# frozen_string_literal: true

module Account
  # A resource request the user sent, with its status and votes.
  class RequestResource < ApplicationResource
    typelize id: :number, title: :string, status: [:string, { enum: ResourceRequest::STATUSES.keys }],
             status_label: :string, votes: :number, date: :string
    attributes :id, :title, :status, :status_label, :votes, :date
  end
end
