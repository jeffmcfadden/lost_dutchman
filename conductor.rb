require_relative 'lib/lost_dutchman'

class ServerImpl < LostDutchman::Conductor::Service
  def initialize()
  end

  def get_next_page_to_crawl(_req, _call)
    LOGGER.info "get_next_page_to_crawl"
    LostDutchman::NextPageResponse.new(next_page_url: "http://example.com")
  end

  def report_crawl_outcome(_req, _call)
    LOGGER.info "report_crawl_outcome"
    LostDutchman::CrawlOutcomeResponse.new
  end
end

port = '0.0.0.0:50051'
s = GRPC::RpcServer.new
s.add_http2_port(port, :this_port_is_insecure)
GRPC.logger.info("... running insecurely on #{port}")
s.handle(ServerImpl.new)
# Runs the server with SIGHUP, SIGINT and SIGQUIT signal handlers to
#   gracefully shutdown.
# User could also choose to run server via call to run_till_terminated
s.run_till_terminated_or_interrupted([1, 'int', 'SIGQUIT'])