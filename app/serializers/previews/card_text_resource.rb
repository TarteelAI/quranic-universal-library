# frozen_string_literal: true

module Previews
  # A translation, transliteration or tafsir on a card (Previews::Card): the entry for ayah 1:2
  # in the text's language and direction, its text cut to Card::TEXT_LIMIT, without footnotes.
  class CardTextResource < ApplicationResource
    typelize kind: [:string, { enum: ['text'] }], granularity: [:string, { enum: ['word', 'ayah'] }]
    attribute(:kind) { 'text' }
    attributes :granularity

    one :locale, resource: LocaleResource
    one :entry, resource: TextEntryResource, source: proc {
      entry = entries.first
      text, truncated = entry.text && Previews.excerpt(entry.text, Card::TEXT_LIMIT)
      entry.with(text:, truncated: truncated || entry.truncated, footnotes: [])
    }
  end
end
