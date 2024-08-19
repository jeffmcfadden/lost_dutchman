require_relative 'shared'
require 'nokogiri'
require 'net/http'
require 'digest'
require 'http'
require 'json'
require_relative 'lib/crawler'
require_relative 'lib/sitemap'

@urls_by_host = {}

Dir.glob("found_urls/*.txt").each do |filename|
  LOGGER.info "Processing found URLs in #{filename}"

  File.open(filename).each_line do |url|
    begin
      url = URI(url.strip.sub(/#.*$/, '')) # Remove fragment, if there. We don't want to be confused by those.
      host = url.host
      @urls_by_host[host] = [] unless @urls_by_host[host]
      @urls_by_host[host] << url
    rescue StandardError
      LOGGER.info "Skipping invalid URL: #{url}"
    end
  end

  File.delete(filename)
  LOGGER.info "Finished: Processing found URLs in #{filename}"
end

@urls_by_host.each do |host, urls|
  LOGGER.info "Start: Processing URLs for #{host}"

  Sitemap.new(host: host).load.add_urls(urls).save

  LOGGER.info "Finished: Processing URLs for #{host}"
end
