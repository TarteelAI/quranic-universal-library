# frozen_string_literal: true

module Start
  # Props of a kit page (Start::KitsController#show): the kit, the platforms and file formats its
  # answers name, the guided setup with those answers, the kits index, and its items in order.
  # `catalogPages` says whether the cards' detail pages are new pages.
  class KitsShowResource < ApplicationResource
    typelize key: :string, title: :string, description: :string, setup_path: :string, kits_path: :string,
             platforms: [:string, { multi: true }], formats: [:string, { multi: true }], catalog_pages: :boolean
    attribute(:key) { |page| page[:kit].key }
    attribute(:title) { |page| page[:kit].title }
    attribute(:description) { |page| page[:kit].description }
    attribute(:setup_path) { |page| Rails.application.routes.url_helpers.start_setup_path(page[:kit].answers) }
    attribute(:kits_path) { Rails.application.routes.url_helpers.start_kits_path }
    attribute(:platforms) do |page|
      page[:kit].setup_answers.platforms.map { |key| GuidedSetup::PLATFORMS.fetch(key).label }
    end
    attribute(:formats) do |page|
      GuidedSetup.result(page[:kit].setup_answers).formats.map do |key|
        Catalog::Taxonomy.label(Catalog::Taxonomy.formats, key)
      end
    end
    many :items, source: proc { self[:entries] }, resource: KitItemResource
    one :vocabularies, source: proc { { languages: [] } }, resource: Catalog::VocabulariesResource
    attribute(:catalog_pages) { PageGroups.enabled?(:catalog) }
  end
end
