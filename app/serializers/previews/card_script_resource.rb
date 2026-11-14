# frozen_string_literal: true

module Previews
  # A Quran script on a card (Previews::Card): one ayah in the script's text and fonts.
  class CardScriptResource < ApplicationResource
    typelize kind: [:string, { enum: ['script'] }],
             granularity: [:string, { enum: ['word', 'ayah'] }],
             rendering: [:string, { enum: ['text', 'html', 'image'] }],
             font_code: [:string, { nullable: true }]
    attribute(:kind) { 'script' }
    attributes :granularity, :rendering, :font_code

    many :fonts, resource: FontFilesResource
    one :ayah, source: proc { ayahs.first }, resource: ScriptAyahResource
  end
end
