# frozen_string_literal: true

module Previews
  # A mushaf layout on a card (Previews::Card): its first page, without the page navigation.
  class CardLayoutResource < ApplicationResource
    typelize kind: [:string, { enum: ['layout'] }]
    attribute(:kind) { 'layout' }

    one :page, resource: CardPageResource
  end
end
