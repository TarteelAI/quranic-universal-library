# frozen_string_literal: true

module Previews
  # The preview of a translation, tafsir or transliteration (Previews::Text): its text for a
  # range of ayahs, in the language and direction `locale` names.
  class TextResource < ApplicationResource
    typelize kind: [:string, { enum: %w[text] }],
             granularity: [:string, { enum: %w[word ayah] }],
             from: :number, to: :number
    attribute(:kind) { 'text' }
    attributes :granularity, :from, :to

    one :locale, resource: LocaleResource
    one :surah, resource: ScriptSurahResource
    many :entries, resource: TextEntryResource
    many :surahs, resource: ScriptSurahResource
  end
end
