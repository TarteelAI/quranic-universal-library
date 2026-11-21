# frozen_string_literal: true

# One file of a font (Fonts::UrlResolver::Source) and its CSS `format()` name.
class FontSourceResource < ApplicationResource
  typelize url: :string, format: "'woff2' | 'woff' | 'truetype' | 'opentype'"
  attributes :url, :format
end
