# frozen_string_literal: true

module Start
  # Props of the guided setup (Start::SetupController#show): the choices of each step, the
  # languages with the number of resources in each, and the answers read from the query string.
  # `catalogPages` says whether the results page is served (the `catalog` group is on).
  class SetupShowResource < ApplicationResource
    many :goals, source: proc { GuidedSetup::GOALS.values }, resource: GoalResource
    many :platforms, source: proc { GuidedSetup::PLATFORMS.values }, resource: PlatformResource
    many :features, source: proc { GuidedSetup::FEATURES.values }, resource: Catalog::OptionResource
    many :scripts, source: proc { GuidedSetup::SCRIPTS.values }, resource: ScriptResource
    many :languages, resource: Catalog::FacetLanguageResource
    one :answers, resource: AnswersResource

    typelize catalog_pages: :boolean
    attribute(:catalog_pages) { PageGroups.enabled?(:catalog) }
  end
end
