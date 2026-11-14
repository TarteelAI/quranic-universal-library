# frozen_string_literal: true

module Previews
  # A surah and the mushaf page it starts on (nil when the mushaf lacks its first word).
  class SurahPageResource < ApplicationResource
    typelize number: :number, name: :string, page: [:number, { nullable: true }]
    attributes :number, :name, :page
  end
end
