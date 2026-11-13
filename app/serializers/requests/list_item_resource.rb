# frozen_string_literal: true

module Requests
  # A request on the public list: what was asked, its status, its votes and whether the current
  # user voted. Requests::ListQuery selects no author or voter, so none can appear here.
  class ListItemResource < ApplicationResource
    typelize id: :number, title: :string, description: :string, type: :string,
             language: [:string, { nullable: true }], status: [:string, { enum: ResourceRequest::STATUSES.keys }],
             status_label: :string, votes: :number, voted: :boolean, date: :string
    attributes :id, :title, :description, :language, :status, :status_label, :voted

    # A catalog type's label; 'other' is the only key that is not one.
    attribute(:type) { |request| Catalog::Taxonomy.type(request.resource_type)&.label || 'Other' }
    attribute(:votes, &:votes_count)
    attribute(:date) { |request| request.created_at.strftime('%-d %B %Y') }
  end
end
