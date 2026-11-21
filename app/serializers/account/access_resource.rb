# frozen_string_literal: true

module Account
  # A resource the user asked to edit. `path` is its contributor tool, once the request is approved.
  class AccessResource < ApplicationResource
    typelize id: :number, tool: [:string, { nullable: true }], name: :string, path: [:string, { nullable: true }],
             approved: :boolean, date: [:string, { nullable: true }]
    attributes :id, :tool, :name, :path, :approved, :date
  end
end
