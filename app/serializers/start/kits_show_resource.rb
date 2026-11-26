# frozen_string_literal: true

module Start
  # Props of a kit page (Start::KitsController#show): the kit, how many of its items are of each
  # resource type, the guided setup with its answers, the kits index, and its items in order.
  # `catalogPages` says whether the cards' detail pages are new pages; `downloadMode` whether the
  # kit's zip needs an account.
  class KitsShowResource < ApplicationResource
    typelize key: :string, title: :string, description: :string, setup_path: :string, kits_path: :string,
             type_counts: [:string, { multi: true }], catalog_pages: :boolean
    attribute(:key) { |page| page[:kit].key }
    attribute(:title) { |page| page[:kit].title }
    attribute(:description) { |page| page[:kit].description }
    attribute(:setup_path) { |page| Rails.application.routes.url_helpers.start_setup_path(page[:kit].answers) }
    attribute(:kits_path) { Rails.application.routes.url_helpers.start_kits_path }
    # "1 recitation", "2 fonts": one per type of the kit's items, in taxonomy order.
    attribute(:type_counts) do |page|
      counts = page[:entries].map { |entry| entry.resource.resource.resource_type }.tally
      Catalog::Taxonomy.types.filter_map do |type|
        count = counts[type.key] or next
        "#{count} #{(count == 1 ? type.label : type.title).sub(/\A(?!Quran\b)\p{Lu}/, &:downcase)}"
      end
    end
    many :items, source: proc { self[:entries] }, resource: KitItemResource
    one :vocabularies, source: proc { { languages: [] } }, resource: Catalog::VocabulariesResource
    attribute(:catalog_pages) { PageGroups.enabled?(:catalog) }
    typelize download_mode: [:string, { enum: DownloadMode::MODES }]
    attribute(:download_mode) { DownloadMode.current }
  end
end
