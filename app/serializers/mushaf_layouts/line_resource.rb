# frozen_string_literal: true

module MushafLayouts
  # One line of a mushaf page (MushafLayouts::Page::Line).
  class LineResource < ApplicationResource
    typelize number: :number, centered: :boolean, surah_number: [:number, { nullable: true }], bismillah: :boolean
    attributes :number, :centered, :surah_number, :bismillah

    many :words, resource: WordResource
  end
end
