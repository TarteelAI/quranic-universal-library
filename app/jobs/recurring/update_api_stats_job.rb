module Recurring
  class UpdateApiStatsJob < ApplicationJob
    queue_as :default
    include Sidekiq::Status::Worker

    def perform(id: nil)
      active_clients = find_clients(id)
      total active_clients.size
      counter = 0

      active_clients.find_each do |api_client|
        begin
          at counter, api_client.name
          api_client.update_api_stats
        rescue Exception => e
          Sentry.capture_exception(e)
        end
      end
    end

    protected

    def find_clients(id)
      list = ApiClient.where(active: true)

      if id
        list.where(id: id)
      else
        list
      end
    end
  end
end