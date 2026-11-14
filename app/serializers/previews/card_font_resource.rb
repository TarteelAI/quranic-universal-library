# frozen_string_literal: true

module Previews
  # A font on a card (Previews::Card): a line drawn in it. That is the start of its sample or,
  # for a font with one file per mushaf page, the first line of words on page 1 in that page's
  # file. `font_code` is the page's mushaf font (V4 Tajweed pages take the colour palette).
  class CardFontResource < ApplicationResource
    SAMPLE_WORDS = 8

    typelize kind: [:string, { enum: ['font'] }], font_code: [:string, { nullable: true }], text: :string
    attribute(:kind) { 'font' }
    attribute(:font_code) { |preview| preview.page&.font_code }
    attribute :text do |preview|
      if preview.page
        preview.page.lines.find { |line| line.words.any? }.words.map(&:text).join(' ')
      else
        preview.sample.text.split.first(SAMPLE_WORDS).join(' ')
      end
    end

    one :font, resource: FontFilesResource
  end
end
