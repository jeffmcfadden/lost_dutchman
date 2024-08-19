class Crawler
  attr_reader :host, :http, :page_urls, :found_urls, :visited_pages

  MAX_PAGES_TO_CRAWL = 50
  MAX_ERROR_COUNT = 7

  def initialize(host:)
    @host = host
    @found_urls = []
    @visited_pages = []
    @error_count = 0

    load_sitemap
  end

  def crawl(skip_cached: false)
    LOGGER.info "Starting crawl for #{host}"

    FileUtils.mkdir_p("page_meta/#{host}")
    FileUtils.mkdir_p("page_content/#{host}")

    @page_urls.shuffle!

    @page_urls.each do |page_url|
      next if @visited_pages.size >= MAX_PAGES_TO_CRAWL
      next if @visited_pages.include?(page_url)
      next if @error_count > MAX_ERROR_COUNT # Something's wrong. Stop crawling.

      meta = fetch_page_meta(page_url, skip_cached: skip_cached)
      if meta && meta[:content_type] == "text/html"
        html_content = fetch_page_content(page_url, skip_cached: skip_cached)
        if html_content.length > 0
          LOGGER.info "Start: Adding links for #{page_url}"
          doc = Nokogiri::HTML(html_content)
          links = doc.css('a').map { |link| link['href'] }.compact.uniq

          processed_links = []

          links.each do |link|
            begin
              uri = URI.join(page_url, link) #.join should handle relative and absolute links, I think.
              processed_links << uri
            rescue StandardError
              LOGGER.info "Skipping invalid link: #{link}"
            end
          end

          LOGGER.info "Finished: Adding links for #{page_url}"

          @found_urls += processed_links.uniq
        end
      else
        LOGGER.info "Skipping content for non-HTML page: #{page_url}"
      end

      @visited_pages << page_url
    end

    http&.close

    save_found_urls
    LOGGER.info "Done crawling for #{host}. Visited #{visited_pages.size} pages."
  end

  private

  def http
    @http ||= HTTP.persistent("https://#{host}").timeout(5).headers("User-Agent" => "Greenshed Crawler/1.0")
  end

  def url_hash(url)
    Digest::SHA256.hexdigest(url.to_s)
  end

  # Used to fetch paths within our persistent connection
  def path_and_query_string(url)
    url.path + (url.query ? "?#{url.query}" : "")
  end

  def load_sitemap
    @page_urls = Sitemap.new(host: host).load.urls.map { |url| URI(url) }

  rescue Errno::ENOENT
    LOGGER.error "No sitemap found for #{host}"

    # If there's no sitemap, we'll start with the homepage and go from there.
    @page_urls = [URI("https://#{host}")] # Fragile, but good enough for now
  end

  def fetch_page_meta(page_url, skip_cached: false)
    LOGGER.info "Fetching page meta: #{page_url}"
    h = url_hash(page_url)

    page_meta_filename = "page_meta/#{host}/#{h}"

    if File.exist?(page_meta_filename) && !skip_cached
      LOGGER.info "Found cached copy of page meta: #{page_url}"
      return JSON.parse(File.read(page_meta_filename), symbolize_names: true)
    end

    begin
      head_response = http.head(path_and_query_string(page_url))

      headers = head_response.headers.to_h

      page_meta = {
        url: page_url.to_s,
        content_type: head_response.content_type.mime_type,
        content_length: head_response.content_length,
        last_modified: headers["last_modified"],
        etag: headers["etag"],
        last_crawl_code: head_response.last_crawl_code
      }

      File.open(page_meta_filename, 'w') { |file| file.write(JSON.dump(page_meta)) }
    rescue StandardError => e
      @error_count += 1
      LOGGER.error "Error fetching page meta: #{page_url}. #{e.message}"
    end

    LOGGER.info "Done fetching page meta: #{page_url}"
    page_meta
  end

  def fetch_page_content(page_url, skip_cached: false)
    LOGGER.info "Fetching page content: #{page_url}"
    h = url_hash(page_url)
    filename = "page_content/#{host}/#{h}"

    if File.exist?(filename) && !skip_cached
      LOGGER.info "Found cached copy of page: #{page_url}"
      return File.read(filename)
    end

    response = http.get(path_and_query_string(page_url))
    LOGGER.info "End: Fetching #{page_url}"

    if response.status.success?
      LOGGER.info "Start: Saving file #{filename}"
      File.open(filename, 'w') { |file| file.write(response.to_s) }
      LOGGER.info "End: Saving file #{filename}"

      response.to_s #Body as string
    elsif response.status.redirect?
      redirected_to_url = response.headers['location']
      @found_urls << redirected_to_url
      LOGGER.info "Redirected to #{redirected_to_url}. Adding to found URLs."
      response.flush
      ""
    else
      @error_count += 1
      LOGGER.error "Failed to fetch page content: #{page_url}. Response code: #{response.last_crawl_code}"
      response.flush # For persistent connection
      ""
    end
  end

  def save_found_urls
    LOGGER.info "Saving found URLs for #{host}"
    File.open("found_urls/#{host}.txt", "w") do |file|
      file.write(found_urls.uniq.join("\n"))
    end
    LOGGER.info "Done saving found URLs for #{host}"
  end
end