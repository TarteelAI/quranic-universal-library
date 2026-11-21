# frozen_string_literal: true

module Previews
  # The preview of a resource shown as a sample of its records (Previews::Records): at most
  # `limit` records, from the chosen surah when `surah` is set.
  class RecordsResource < ApplicationResource
    typelize kind: [:string, { enum: %w[records] }], limit: :number, surah: { nullable: true }
    attribute(:kind) { 'records' }
    attributes :limit

    one :surah, resource: ScriptSurahResource
    many :surahs, resource: ScriptSurahResource
    one :locale, resource: LocaleResource
    many :records, resource: RecordResource
  end
end
