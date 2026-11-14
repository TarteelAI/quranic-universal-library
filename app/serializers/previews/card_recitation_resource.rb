# frozen_string_literal: true

module Previews
  # A recitation on a card (Previews::Card): the tracks of its surah, one file for a surah
  # recitation or one per ayah for an ayah-by-ayah one, which the card plays in order.
  class CardRecitationResource < ApplicationResource
    typelize kind: [:string, { enum: ['recitation'] }],
             granularity: [:string, { enum: ['surah', 'ayah'] }],
             highlights: :boolean, tracks: [:string, { multi: true }]
    attribute(:kind) { 'recitation' }
    attributes :granularity, :highlights, :tracks

    one :surah, resource: ScriptSurahResource
  end
end
