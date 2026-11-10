# frozen_string_literal: true

module Previews
  # One mushaf page with its fonts and the page each surah starts on (Previews::MushafPage::Value).
  class MushafPageResource < ApplicationResource
    typelize number: :number, pages_count: :number, font_code: :string
    attributes :number, :pages_count, :font_code

    typelize text_font: { nullable: true }
    one :text_font, resource: FontFilesResource
    one :surah_name_font, resource: FontFilesResource
    one :surah_header_font, resource: FontFilesResource
    one :bismillah_font, resource: FontFilesResource

    many :lines, resource: MushafLayouts::LineResource
    many :surahs, resource: SurahPageResource
  end
end
