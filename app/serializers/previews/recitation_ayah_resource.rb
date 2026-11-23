# frozen_string_literal: true

module Previews
  # One ayah of a recitation preview: its text, the track it is in and its times in that track
  # (milliseconds; null when unknown, `to` null for the end of the track).
  class RecitationAyahResource < ApplicationResource
    typelize key: :string, number: :number, text: :string, track: [:number, { nullable: true }],
             from: [:number, { nullable: true }], to: [:number, { nullable: true }]
    attributes :key, :number, :text, :track, :from, :to
  end
end
