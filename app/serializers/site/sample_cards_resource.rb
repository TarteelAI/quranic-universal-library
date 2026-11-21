# frozen_string_literal: true

module Site
  # The preview of a home page card that shows several resources side by side (the scripts, the
  # translations): each one's card preview (Previews::Card) with its label.
  class SampleCardsResource < ApplicationResource
    typelize kind: [:string, { enum: ['cards'] }]
    attribute(:kind) { 'cards' }

    many :cards, resource: SampleCardResource
  end
end
