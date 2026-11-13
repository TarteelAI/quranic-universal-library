# frozen_string_literal: true

module Previews
  # A recitation on a card (Previews::Card): the first track of its surah, which the card plays.
  class CardRecitationResource < ApplicationResource
    typelize kind: [:string, { enum: %w[recitation] }],
             granularity: [:string, { enum: %w[surah ayah] }],
             highlights: :boolean, track: :string
    attribute(:kind) { 'recitation' }
    attributes :granularity, :highlights
    attribute(:track) { |preview| preview.tracks.first }

    one :surah, resource: ScriptSurahResource
  end
end
