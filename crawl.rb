require_relative 'shared'
require 'nokogiri'
require 'net/http'
require 'digest'
require 'http'
require 'json'
require_relative 'lib/crawler'
require_relative 'lib/sitemap'

PROCESS_COUNT = 32

hosts = Dir.glob("sitemaps/*.txt").to_a.sample(128).map{ |filename| filename.gsub( "sitemaps/", "").gsub(".txt", "") }
pids = []

# Override hosts with ARGV if provided
hosts = Array(ARGV) if ARGV[0]

LOGGER.info "Starting to crawl #{hosts.size} hosts with #{PROCESS_COUNT} processes..."
LOGGER.info "Hosts: #{hosts.join(", ")}"

sleep 3

hosts.group_by{|i| rand(PROCESS_COUNT) % PROCESS_COUNT }.each do |i, hosts|
  pids << fork do
    LOGGER.info "Spawing process..."
    hosts.each do |host|
      Crawler.new(host: host).crawl
    end
  end
end

# Wait for all child processes to complete
pids.each do |pid|
  Process.wait(pid)
end

puts "All crawlers have finished."