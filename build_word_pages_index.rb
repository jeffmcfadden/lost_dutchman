require_relative 'shared'
require 'nokogiri'
require 'net/http'
require 'digest'
require 'http'
require 'json'
require_relative 'lib/crawler'
require_relative 'lib/sitemap'

word_pages_index = {}

LOGGER.info "Started: Processing page words."
Dir.glob("page_words/**/*.json").each_with_index do |filename, file_index|
  next if File.directory?(filename)
  LOGGER.info "Start: Processing #{filename}"

  url_hash = filename.split("/").last.gsub(".json", "")

  word_map = JSON.parse(File.read(filename))

  word_map.each do |word, positions|
    word_pages_index[word] ||= {}
    word_pages_index[word][url_hash] ||= 0
    word_pages_index[word][url_hash] += 1
  end
end
LOGGER.info "Finished: Processing page words."

File.open( "word_pages_index.json", "w") do |f|
  f.write(word_pages_index.to_json)
end
LOGGER.info "Saved word pages index to word_pages_index.json"