# frozen_string_literal: true

module Content
  # Props of the changelog (Content::ChangelogController#index): one page of entries.
  class ChangelogIndexResource < ApplicationResource
    typelize page: :number, pages: :number
    attributes :page, :pages
    many :entries, resource: ChangelogEntryResource
  end
end
