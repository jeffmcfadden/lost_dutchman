require_relative 'shared'
require 'nokogiri'
require 'net/http'
require 'digest'
require 'http'
require 'json'
require_relative 'lib/crawler'
require_relative 'lib/sitemap'

LOGGER.info "Started: Loading word pages index..."
@index = JSON.parse(File.open("word_pages_index.json").read)
LOGGER.info "Finished: Loading word pages index"

query_words = ARGV.map{ |word| word.downcase }

results = {}

# Get results that are the intersection of all possible pages
possible_pages = query_words.collect{ |word| @index[word].keys }.reduce(&:&)

page_info = possible_pages.collect{ |p|
  File.open( "page_meta/#{p}" ).read
}