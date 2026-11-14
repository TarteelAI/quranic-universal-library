# frozen_string_literal: true

module Previews
  # A mushaf page on a card (Previews::MushafPage::Value): its lines and fonts.
  class CardPageResource < ApplicationResource
    typelize number: :number, font_code: :string
    attributes :number, :font_code

    typelize text_font: { nullable: true }
    one :text_font, resource: FontFilesResource
    one :surah_name_font, resource: FontFilesResource
    one :surah_header_font, resource: FontFilesResource
    one :bismillah_font, resource: FontFilesResource

    many :lines, resource: MushafLayouts::LineResource
  end
end
