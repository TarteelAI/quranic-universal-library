# frozen_string_literal: true

module Account
  # A file the user downloaded. `path` is the resource's page, null when it is no longer published.
  class DownloadResource < ApplicationResource
    typelize id: :number, type: [:string, { nullable: true }], name: :string, path: [:string, { nullable: true }],
             date: [:string, { nullable: true }], update_available: :boolean
    attributes :id, :type, :name, :path, :date, :update_available
  end
end
