# frozen_string_literal: true

module Content
  # Props of a changelog entry page (Content::ChangelogController#show).
  class ChangelogShowResource < ApplicationResource
    one :entry, resource: ChangelogEntryDetailResource
  end
end
