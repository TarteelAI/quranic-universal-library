# frozen_string_literal: true

module Catalog
  # A published changelog entry of a resource (Catalog::ResourcePage::Change), without its author.
  class ResourceChangeResource < ApplicationResource
    typelize id: :number, title: :string, excerpt: :string, date: :string, path: :string
    attributes :id, :title, :excerpt
    attribute(:date) { |change| change.date.strftime(ResourcePage::DATE_FORMAT) }
    # The entry's page: the new one while the `content` page group is on, else the old one.
    attribute(:path) do |change|
      routes = Rails.application.routes.url_helpers
      PageGroups.enabled?(:content) ? routes.changelog_entry_page_path(change.id) : routes.change_log_path(change.id)
    end
  end
end
