require 'nokogiri'
require 'net/http'
require 'logger'
require 'digest'
require 'http'
require 'json'

LOGGER = Logger.new($stdout)

MAX_PAGES_TO_CRAWL = 500

HOST_ALLOW_LIST = ["thegreenshed.org", "blog.ayjay.org"] #, "www.ayjay.org", "ayjay.org"]

@http = {}

# Obviously this will break down pretty quickly if we're trying to crawl the entire internet.
HOST_ALLOW_LIST.each do |host|
  @http[host] = HTTP.persistent("https://#{host}").headers("User-Agent" => "Greenshed Crawler/1.0")
end

@link_map = {}
@visited = []
@first_page = URI("https://thegreenshed.org")

def http_for(url)
  @http[url.host]
end

def url_hash(url)
  Digest::SHA256.hexdigest(url.to_s)
end

def path_and_query_string(url)
  url.path + (url.query ? "?#{url.query}" : "")
end

def fetch_page_meta(url, skip_cached: false)
  LOGGER.info "Fetching page meta: #{url}"
  h = url_hash(url)

  filename = "page_meta/#{h}"

  if File.exist?(filename) && !skip_cached
    LOGGER.info "Found cached copy of page meta: #{url}"
    return JSON.parse(File.read(filename), symbolize_names: true)
  end

  head_response = http_for(url).head(path_and_query_string(url))

  headers = head_response.headers.to_h

  page_meta = {
    url: url.to_s,
    content_type: head_response.content_type.mime_type,
    content_length: head_response.content_length,
    last_modified: headers["last_modified"],
    etag: headers["etag"],
    last_crawl_code: head_response.last_crawl_code
  }

  File.open(filename, 'w') { |file| file.write(JSON.dump(page_meta)) }

  LOGGER.info "Done fetching page meta: #{url}"
  page_meta
end

# @param [URI] url
def fetch_page(url, skip_cached: false)
  LOGGER.info "Start: Fetching #{url}"
  h = url_hash(url)

  page_meta = fetch_page_meta(url, skip_cached: skip_cached)
  if page_meta[:content_type] != "text/html"
    LOGGER.info "Skipping non-HTML page: #{url} (#{page_meta[:content_type]})"
    return ""
  end

  LOGGER.info "Fetching page content: #{url}"
  filename = "page_content/#{h}"

  if File.exist?(filename) && !skip_cached
    LOGGER.info "Found cached copy of page: #{url}"
    @visited << h
    return File.read(filename)
  end

  response = http_for(url).get(path_and_query_string(url))
  @visited << h

  LOGGER.info "End: Fetching #{url}"

  if response.status.success?
    LOGGER.info "Start: Saving file #{filename}"
    File.open(filename, 'w') { |file| file.write(response.to_s) }
    LOGGER.info "End: Saving file #{filename}"

    response.to_s #Body as string
  else
    response.flush # For persistent connection
    nil
  end

end

def extract_links(html, page_url)
  LOGGER.info "Extracting links"
  doc = Nokogiri::HTML(html)
  links = doc.css('a').map { |link| link['href'] }.compact.uniq

  processed_links = []

  links.each do |link|
    begin
      uri = URI(link)
      # If the links are relative, we need to make them absolute
      uri.host ||= page_url.host
      uri.scheme ||= page_url.scheme
      processed_links << uri
    rescue StandardError
      LOGGER.info "Skipping invalid link: #{link}"
    end
  end

  processed_links.uniq
end

def update_link_map(page_url, links)
  # For each link in the page, create an entry in the map, indicating the this page points to it.
  links.each do |link|
    h = url_hash(link)
    ph = url_hash(page_url)
    @link_map[h] = { forward_link_count: 1, backlinks: [], url: link } unless @link_map.key?(h)
    @link_map[h][:backlinks] << ph unless @link_map[h][:backlinks].include?(ph)
  end
end

# @param [URI] page_url
def process_page(page_url, skip_cached: false)
  LOGGER.info "Start: Processing page #{page_url}"

  h = url_hash(page_url)
  @link_map[h] = { forward_link_count: 1, backlinks: [], url: page_url } unless @link_map.key?(h)

  body = fetch_page(page_url, skip_cached: skip_cached)
  links = extract_links(body, page_url)

  @link_map[h][:forward_link_count] = links.size + 1 # So we never divide by zero later


  update_link_map(page_url, links)

  LOGGER.info "Done: Processing page #{page_url}"

  next_pages = []
  links.each do |uri|
    h = url_hash(uri)
    next if @visited.size >= MAX_PAGES_TO_CRAWL
    next if @visited.include?(h)
    next unless HOST_ALLOW_LIST.include?(uri.host)

    next_pages << (uri)
  end

  LOGGER.info "Next pages:"
  LOGGER.info next_pages

  next_pages.each{ |next_page| process_page(next_page, skip_cached: skip_cached) }
end

process_page(@first_page, skip_cached: false)

@http.each(&:close) # Cleanup

LOGGER.info "Finished."

LOGGER.info "Visited a total of #{@visited.size} pages"

# LOGGER.info "Link Map:"
#
# @link_map.sort_by{ |k, v| v[:backlinks].size }.reverse.each do |k, v|
#   LOGGER.info "#{v[:url]}: #{v[:forward_link_count]} forward links, #{v[:backlinks].size} backlinks"
# end
#
# LOGGER.info "--------------------"
#
# @link_map.keys.sample(10).each do |k|
#   LOGGER.info "Backlinks for #{@link_map[k][:url]}:"
#   @link_map[k][:backlinks].each do |backlink|
#     LOGGER.info "  #{@link_map[backlink][:url] rescue "Unknown"}"
#   end
# end

# Page Rank Algorithm
damping_factor = 0.85
number_of_documents = @link_map.keys.size

# Initial Page Rank
LOGGER.info "Start: Setting default Page Rank"
@link_map.each do |k,v|
  @link_map[k][:page_rank] = 1 / @link_map.keys.size.to_f
end
LOGGER.info "Finished: Setting default Page Rank"

# Now apply the algorithm.
LOGGER.info "Start: Calculating Page Rank"
page_rank_calculation_start = Time.now.to_f
10.times do |i|
  LOGGER.info "Iteration #{i}"
  @link_map.each do |k, v|
    page_rank = (1 - damping_factor) / number_of_documents

    page_rank += (damping_factor * v[:backlinks].collect{ |backlink|
      @link_map[backlink][:page_rank] / @link_map[backlink][:forward_link_count]
    }.sum)

    @link_map[k][:page_rank] = page_rank
  end
end
LOGGER.info "Finished: Calculating Page Rank after #{Time.now.to_f - page_rank_calculation_start} seconds"

@link_map.sort_by{ |k, v| v[:page_rank] }.reverse.first(20).each do |k, v|
  LOGGER.info "#{v[:url]}: #{v[:page_rank]}"
end