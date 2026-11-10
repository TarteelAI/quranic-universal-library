# frozen_string_literal: true

module Catalog
  # A published changelog entry of a resource (Catalog::ResourcePage::Change), without its author.
  class ResourceChangeResource < ApplicationResource
    typelize id: :number, title: :string, excerpt: :string, date: :string, path: :string
    attributes :id, :title, :excerpt
    attribute(:date) { |change| change.date.strftime(ResourcePage::DATE_FORMAT) }
    # The entry's page (an old page).
    attribute(:path) { |change| Rails.application.routes.url_helpers.change_log_path(change.id) }
  end
end
