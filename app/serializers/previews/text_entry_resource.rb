# frozen_string_literal: true

module Previews
  # One entry of a text preview: an ayah, or the group of ayahs a tafsir entry covers. `text` is
  # sanitized HTML (null when the resource has none for these ayahs); `truncated` says a long
  # tafsir entry was cut. Word-by-word resources fill `words` instead.
  class TextEntryResource < ApplicationResource
    typelize key: :string, text: [:string, { nullable: true }], truncated: :boolean
    attributes :key, :text, :truncated

    many :ayahs, resource: TextAyahResource
    many :footnotes, resource: TextFootnoteResource
    many :words, resource: TextWordResource
  end
end
