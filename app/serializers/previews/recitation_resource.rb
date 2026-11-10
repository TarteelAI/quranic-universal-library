# frozen_string_literal: true

module Previews
  # The preview of a recitation (Previews::Recitation): the audio files of one surah and its
  # ayahs. `highlights` says whether the ayahs carry times, so the player can show the ayah
  # being recited.
  class RecitationResource < ApplicationResource
    typelize kind: [:string, { enum: %w[recitation] }],
             granularity: [:string, { enum: %w[surah ayah] }],
             highlights: :boolean, tracks: [:string, { multi: true }]
    attribute(:kind) { 'recitation' }
    attributes :granularity, :highlights, :tracks

    one :surah, resource: ScriptSurahResource
    many :ayahs, resource: RecitationAyahResource
    many :surahs, resource: ScriptSurahResource
  end
end
