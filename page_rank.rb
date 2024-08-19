require_relative 'shared'
require 'nokogiri'
require 'net/http'
require 'digest'
require 'http'
require 'json'
require_relative 'lib/crawler'
require_relative 'lib/page'
require_relative 'lib/sitemap'

@pages = {}

page_metas = Dir.glob("page_meta/*").to_a

@number_of_pages = page_metas.size
damping_factor = 0.85

LOGGER.info "Start: Loading page meta data..."
page_metas.each do |filename|
  next if File.directory?(filename)
  begin
    meta = JSON.parse(File.read(filename), symbolize_names: true)
    h = Digest::SHA256.hexdigest(meta[:url])
    @pages[h] = Page.new(url: meta[:url])
  rescue StandardError => e
    LOGGER.error "Error loading page meta data from #{filename}: #{e.message}"
  end
end
LOGGER.info "Finished: Loading page meta data. We have #{@number_of_pages} pages."

# Load up the forward links, from the html content
LOGGER.info "Start: Loading HTML content and extracting links..."
@pages.each do |k, page|
  page.load_html_content
  page.extract_links
end
LOGGER.info "Finished: Loading HTML content and extracting links."

LOGGER.info "Start: Checking for missing pages..."
@pages.collect{ |k,p| p.links }.flatten.uniq.each do |link|
  h = Digest::SHA256.hexdigest(link.to_s)
  if !@pages.key?(h)
    @pages[h] = Page.new(url: link)
  end
end
LOGGER.info "Finished: Checking for missing pages."

# Load up the backlinks
LOGGER.info "Start: Loading backlinks..."
@pages.each do |k, page|
  page.links.each do |link|
    h = Digest::SHA256.hexdigest(link.to_s)
    if @pages.key?(h)
      if page.url.host != link.host # Has to be a link from another site
        @pages[h].backlinks << page.url
      end
    end
  end
end
LOGGER.info "Finished: Loading backlinks."

LOGGER.info "Start: Setting base page rank..."
@base_page_rank  = (1 - damping_factor) / @number_of_pages
@pages.each do |k, page|
  page.page_rank = @base_page_rank
end
LOGGER.info "Finished: Setting base page rank."

LOGGER.info "Start: Calculating page rank..."

50.times do
  @pages.each do |k, page|
    page_rank = @base_page_rank + (damping_factor * page.backlinks.collect{ |backlink|
      h = Digest::SHA256.hexdigest(backlink.to_s)
      backlink_page = @pages[h]
      backlink_page.nil? ? 0 : backlink_page.page_rank / (backlink_page.links.size + 1)
    }.sum)

    @pages[k].page_rank = page_rank
  end
end
LOGGER.info "Finished: Calculating page rank."

LOGGER.info "Top pages by page rank:"
@pages.sort_by{ |k, v| v.page_rank }.reverse.first(50).each do |k, v|
  LOGGER.info "#{v.page_rank * 10000} : #{v.backlinks.size} : #{v.url}"
  # LOGGER.info "  #{v.backlinks.collect{ |b| b.host }.uniq.join(", ")}"
end