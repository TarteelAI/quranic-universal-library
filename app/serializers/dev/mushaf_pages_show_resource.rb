# frozen_string_literal: true

module Dev
  # Props of the development-only mushaf page spike (Dev::MushafPagesController#show).
  class MushafPagesShowResource < ApplicationResource
    typelize resource_id: :number, name: :string, font_code: :string, page: :number, pages_count: :number
    attributes :resource_id, :name, :font_code, :page, :pages_count

    many :lines, resource: MushafLayouts::LineResource
    typelize text_font: { nullable: true }
    one :text_font, resource: FontFilesResource
    one :surah_name_font, resource: FontFilesResource
    one :surah_header_font, resource: FontFilesResource
    one :bismillah_font, resource: FontFilesResource
  end
end
