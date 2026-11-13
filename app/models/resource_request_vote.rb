# frozen_string_literal: true

# One user's vote on a resource request. The unique index on the pair keeps it one row per user and
# request; Requests::RequestsController#vote inserts with ON CONFLICT DO NOTHING.
class ResourceRequestVote < ApplicationRecord
  belongs_to :resource_request
  belongs_to :user
end
