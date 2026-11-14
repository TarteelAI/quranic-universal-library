# frozen_string_literal: true

module Previews
  # The preview of a Quran script (Previews::Script): a range of ayahs of one surah.
  # `rendering` says how to draw the text: plain text, tajweed HTML (sanitized <rule> tags) or
  # one image per word.
  class ScriptResource < ApplicationResource
    typelize kind: [:string, { enum: %w[script] }],
             granularity: [:string, { enum: %w[word ayah] }],
             rendering: [:string, { enum: %w[text html image] }],
             font_code: [:string, { nullable: true }],
             from: :number, to: :number
    attribute(:kind) { 'script' }
    attributes :granularity, :rendering, :font_code, :from, :to

    many :fonts, resource: FontFilesResource
    one :surah, resource: ScriptSurahResource
    many :ayahs, resource: ScriptAyahResource
    many :surahs, resource: ScriptSurahResource
  end
end
