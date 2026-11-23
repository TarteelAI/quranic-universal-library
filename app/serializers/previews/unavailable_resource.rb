# frozen_string_literal: true

module Previews
  # A resource whose preview cannot be drawn (Previews::Unavailable), and why.
  class UnavailableResource < ApplicationResource
    typelize kind: [:string, { enum: %w[unavailable] }], reason: :string
    attribute(:kind) { 'unavailable' }
    attributes :reason
  end
end
