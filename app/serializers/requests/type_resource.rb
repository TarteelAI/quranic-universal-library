# frozen_string_literal: true

module Requests
  # A kind of resource the request form offers (a Catalog::Taxonomy::Option), with what a request
  # of that kind asks for (ResourceRequest.details), so the form shows the fields the server checks.
  class TypeResource < ApplicationResource
    typelize key: :string, label: :string, author: [:string, { nullable: true, enum: ['required', 'optional'] }],
             source_required: :boolean
    attributes :key, :label
    attribute(:author) { |type| ResourceRequest.details(type.key).author }
    attribute(:source_required) { |type| ResourceRequest.details(type.key).source_required }
  end
end
