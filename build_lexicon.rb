require_relative 'shared'
require 'nokogiri'
require 'net/http'
require 'digest'
require 'http'
require 'json'
require_relative 'lib/crawler'
require_relative 'lib/sitemap'

@lexicon = []

started_at = Time.now.to_f
LOGGER.info "Starting: Building lexicon..."
Dir.glob("page_content/**/*").each do |filename|
  next if File.directory?(filename)

  LOGGER.info "Processing #{filename}"

  content = File.read(filename)
  doc = Nokogiri::HTML(content)

  doc.css('body').each do |body|
    begin
      body.text.split.each do |word|
        next unless word.length < 20
        @lexicon << word.downcase
      end
    rescue StandardError => e
      LOGGER.info "Error processing #{filename}: #{e}"
    end
  end
end
LOGGER.info "Finished: Building lexicon"

LOGGER.info "Starting: Removing duplicates and punctuation from lexicon..."

@lexicon.uniq!
@lexicon.each_with_index do |word, index|
  @lexicon[index] = word.gsub(/\W/, '')
end
@lexicon.uniq!

LOGGER.info "Finished: Removing duplicates from lexicon"

File.open( "lexicon.txt", "w") do |f|
  f.write(@lexicon.join("\n"))
end
LOGGER.info "Saved lexicon to lexicon.txt"

LOGGER.info "Lexicon complete after #{Time.now.to_f - started_at} seconds"

LOGGER.info "Lexicon size: #{@lexicon.size}"
