# frozen_string_literal: true

module Previews
  # The Arabic of one ayah in a text preview.
  class TextAyahResource < ApplicationResource
    typelize key: :string, text: :string
    attributes :key, :text
  end
end
