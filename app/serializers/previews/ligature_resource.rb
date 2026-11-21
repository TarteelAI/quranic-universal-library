# frozen_string_literal: true

module Previews
  # A name a font draws as one glyph, and the text to type for it.
  class LigatureResource < ApplicationResource
    typelize name: :string, text: :string
    attributes :name, :text
  end
end
