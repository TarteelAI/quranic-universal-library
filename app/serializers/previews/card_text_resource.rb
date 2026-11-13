# frozen_string_literal: true

module Previews
  # A translation on a card (Previews::Card): one ayah with its text, in the text's language
  # and direction.
  class CardTextResource < ApplicationResource
    typelize kind: [:string, { enum: %w[text] }], granularity: [:string, { enum: %w[word ayah] }]
    attribute(:kind) { 'text' }
    attributes :granularity

    one :locale, resource: LocaleResource
    one :entry, source: proc { entries.first }, resource: TextEntryResource
  end
end
