# frozen_string_literal: true

module Previews
  # A translation footnote: sanitized HTML.
  class TextFootnoteResource < ApplicationResource
    typelize id: :number, text: :string
    attributes :id, :text
  end
end
