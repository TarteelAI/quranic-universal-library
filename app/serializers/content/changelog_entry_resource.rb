# frozen_string_literal: true

module Content
  # A published changelog entry in the list (Content::Changelog::Entry), without its body.
  class ChangelogEntryResource < ApplicationResource
    typelize id: :number, title: :string, excerpt: :string, date: :string, path: :string
    attributes :id, :title, :excerpt
    attribute(:date) { |entry| entry.date.strftime(Catalog::ResourcePage::DATE_FORMAT) }
    attribute(:path) { |entry| Rails.application.routes.url_helpers.changelog_entry_page_path(entry.id) }

    typelize resource: { nullable: true }
    one :resource, resource: ChangelogResourceLinkResource
  end
end
