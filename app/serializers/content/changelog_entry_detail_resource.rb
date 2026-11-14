# frozen_string_literal: true

module Content
  # A published changelog entry on its own page (Content::Changelog::Entry). The body is editor
  # HTML reduced to prose (Content::Prose).
  class ChangelogEntryDetailResource < ApplicationResource
    typelize id: :number, title: :string, date: :string, body: :string
    attributes :id, :title
    attribute(:date) { |entry| entry.date.strftime(Catalog::ResourcePage::DATE_FORMAT) }
    attribute(:body) { |entry| Prose.sanitize(entry.text) }

    typelize resource: { nullable: true }
    one :resource, resource: ChangelogResourceLinkResource
  end
end
