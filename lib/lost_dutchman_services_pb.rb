# Generated by the protocol buffer compiler.  DO NOT EDIT!
# Source: lost_dutchman.proto for package 'lost_dutchman'


module LostDutchman
  module Conductor
    class Service

      include ::GRPC::GenericService

      self.marshal_class_method = :encode
      self.unmarshal_class_method = :decode
      self.service_name = 'lost_dutchman.Conductor'

      rpc :GetNextPageToCrawl, ::LostDutchman::NextPageRequest, ::LostDutchman::NextPageResponse
      rpc :ReportCrawlOutcome, ::LostDutchman::CrawlOutcome, ::LostDutchman::CrawlOutcomeResponse
    end

    Stub = Service.rpc_stub_class
  end
end
