# frozen_string_literal: true

module Previews
  # One word of a script preview: its text in its font, or its image.
  class ScriptTokenResource < ApplicationResource
    typelize id: :number, text: [:string, { nullable: true }], font: [:string, { nullable: true }],
             image_url: [:string, { nullable: true }]
    attributes :id, :text, :font, :image_url
  end
end
