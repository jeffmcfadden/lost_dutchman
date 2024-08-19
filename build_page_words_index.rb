require_relative 'shared'
require 'nokogiri'
require 'net/http'
require 'digest'
require 'http'
require 'json'
require_relative 'lib/crawler'
require_relative 'lib/sitemap'

@lexicon = File.open("lexicon.txt").read.split("\n")

Dir.glob("page_content/**/*").each_with_index do |filename, file_index|
  next if File.directory?(filename)

  LOGGER.info "Start: Processing words in #{filename}"

  host = filename.gsub("page_content/", "" ).split("/").first
  FileUtils.mkdir_p("page_words/#{host}")

  word_map = {}

  content = File.read(filename)
  doc = Nokogiri::HTML(content)

  doc.css('body').each do |body|
    body.text.split.each_with_index do |word, i|
      word = word.downcase

      if word_map.has_key?(word) # Should be faster than checking the lexicon
        word_map[word] << i
        next
      end

      next unless @lexicon.include?(word)

      # Setup the default
      word_map[word] = [i]
    end
  end

  last_filename_part = filename.split("/").last

  File.open("page_words/#{host}/#{last_filename_part}.json", "w") do |f|
    f.write(word_map.to_json)
  end

  LOGGER.info "Finished: Processing words in #{filename}"
end