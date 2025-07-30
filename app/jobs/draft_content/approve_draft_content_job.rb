# frozen_string_literal: true
# This Job handle Draft::Content Table (import data from draft::content)

module DraftContent
  class ApproveDraftContentJob < ApplicationJob
    sidekiq_options retry: 1, backtrace: true

    def perform(resource_content_id)
      Draft::Content
        .where(resource_content_id: resource_content_id, imported: false)
        .find_each do |draft|
        draft.import!
      end

      ResourceContent.find(resource_content_id).touch
    end
  end
end