require_relative 'shared'
require 'nokogiri'
require 'net/http'
require 'digest'
require 'http'
require 'json'
require_relative 'lib/crawler'
require_relative 'lib/page'
require_relative 'lib/pages_database'
require_relative 'lib/sitemap'

PagesDatabase.main.import_page_meta