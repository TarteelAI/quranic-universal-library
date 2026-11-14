# frozen_string_literal: true

module Content
  # An h2 or h3 of a docs body, for the contents list: its id in the body, text and level.
  class DocHeadingResource < ApplicationResource
    typelize id: :string, text: :string, level: :number
    attributes :id, :text, :level
  end
end
