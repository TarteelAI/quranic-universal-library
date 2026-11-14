# frozen_string_literal: true

module Content
  # The resource of a changelog entry (Content::Changelog::Resource). The path is the detail page,
  # null while the resource is not published.
  class ChangelogResourceLinkResource < ApplicationResource
    typelize name: :string, path: [:string, { nullable: true }]
    attributes :name, :path
  end
end
