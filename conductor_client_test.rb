require_relative 'lib/lost_dutchman'

stub = LostDutchman::Conductor::Stub.new('localhost:50051', :this_channel_is_insecure)

5.times {
  resp = stub.get_next_page_to_crawl(LostDutchman::NextPageRequest.new)
  LOGGER.info "get_next_page_to_crawl: #{resp.inspect}"
  sleep 5
}