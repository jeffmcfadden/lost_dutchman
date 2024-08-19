require_relative 'shared'
require 'nokogiri'
require 'net/http'
require 'digest'
require 'http'
require 'json'
require_relative 'lib/crawler'
require_relative 'lib/sitemap'

sitemaps = Dir.glob("sitemaps/**/*.txt").to_a
page_metas = Dir.glob("page_meta/**/*").to_a
page_contents = Dir.glob("page_content/**/*").to_a

LOGGER.info "The repository has #{sitemaps.size} sitemaps, #{page_metas.size} page metas, and #{page_contents.size} page contents."