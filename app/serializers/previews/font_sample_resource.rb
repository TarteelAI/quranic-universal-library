# frozen_string_literal: true

module Previews
  # A font's sample text and where it comes from (nil for the editor's own sample).
  class FontSampleResource < ApplicationResource
    typelize text: :string, source: [:string, { nullable: true }]
    attributes :text, :source
  end
end
