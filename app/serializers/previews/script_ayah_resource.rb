# frozen_string_literal: true

module Previews
  # One ayah of a script preview: its text (ayah-level scripts) or its words.
  class ScriptAyahResource < ApplicationResource
    typelize key: :string, number: :number, text: [:string, { nullable: true }], font: [:string, { nullable: true }]
    attributes :key, :number, :text, :font

    many :words, resource: ScriptTokenResource
  end
end
