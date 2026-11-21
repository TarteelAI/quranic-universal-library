# frozen_string_literal: true

module Previews
  # One word of a word-by-word text preview: the Arabic word and its plain-text translation or
  # transliteration.
  class TextWordResource < ApplicationResource
    typelize id: :number, arabic: :string, text: :string
    attributes :id, :arabic, :text
  end
end
