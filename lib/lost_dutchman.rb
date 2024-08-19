require 'nokogiri'
require 'http'
require 'json'
require 'grpc'
require 'digest'
require 'logger'

LOGGER = Logger.new($stdout)

require_relative 'crawler'
require_relative 'page'
require_relative 'pages_database'
require_relative 'sitemap'
require_relative 'lost_dutchman_pb'
require_relative 'lost_dutchman_services_pb'