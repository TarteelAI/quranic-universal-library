# frozen_string_literal: true

module Previews
  # The preview of a font (Previews::Font): its files, a sample or a mushaf page, its ligatures.
  class FontResource < ApplicationResource
    typelize kind: [:string, { enum: %w[font] }], view: [:string, { enum: Font::VIEWS }]
    attribute(:kind) { 'font' }
    attributes :view

    one :font, resource: FontFilesResource
    typelize sample: { nullable: true }
    one :sample, resource: FontSampleResource
    many :ligatures, resource: LigatureResource
    typelize page: { nullable: true }
    one :page, resource: MushafPageResource
  end
end
