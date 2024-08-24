class AsyncResourceActionJob < ApplicationJob
  queue_as :default

  def perform(resource, action)
    resource.send(action)
  end
end