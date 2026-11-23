# frozen_string_literal: true

module Start
  # Props of the guided setup's results (Start::SetupController#results): what the answers say
  # (goal, platform and format labels), the link back to the flow with the answers kept, and one
  # section for each item of the needs checklist (GuidedSetup.result) with its first cards.
  class SetupResultsResource < ApplicationResource
    typelize goals: [:string, { multi: true }], platforms: [:string, { multi: true }],
             formats: [:string, { multi: true }], edit_path: :string, total: :number
    attribute(:goals) { |page| page[:answers].goals.map { |key| GuidedSetup::GOALS.fetch(key).label } }
    attribute(:platforms) { |page| page[:answers].platforms.map { |key| GuidedSetup::PLATFORMS.fetch(key).label } }
    attribute(:formats) do |page|
      page[:result].formats.map { |key| Catalog::Taxonomy.label(Catalog::Taxonomy.formats, key) }
    end
    attribute :edit_path do |page|
      query = page[:answers].query.map { |key, value| "#{key}=#{value}" }.join('&')
      "#{Rails.application.routes.url_helpers.start_setup_path}?#{query}"
    end

    many :sections, resource: SetupSectionResource
    # Distinct resources over every section.
    attribute :total do |page|
      page[:sections].flat_map { |section| section.search.matches.map { |row| row.resource.id } }.uniq.size
    end

    one :vocabularies, source: proc { { languages: [] } }, resource: Catalog::VocabulariesResource
  end
end
