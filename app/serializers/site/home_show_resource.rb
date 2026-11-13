# frozen_string_literal: true

module Site
  # Props of the home page (Site::HomeController#show): the catalog counts, the categories with
  # their counts, the data showcase, the apps of the apps showcase, three contribution tools, the
  # guided setup's goals and the first starter kits, and the links that depend on the page groups.
  class HomeShowResource < ApplicationResource
    # The preview each showcase type's tab shows (Previews.for), by type.
    PREVIEWS = {
      'recitation' => 'Previews::RecitationResource', 'mushaf-layout' => 'Previews::MushafLayoutResource',
      'translation' => 'Previews::TextResource', 'morphology' => 'Previews::RecordsResource',
    }.freeze

    typelize resources: :number, languages: :number, recitations: :number, apps_count: :number,
             catalog_pages: :boolean, apps_page: :boolean, content_pages: :boolean, start_pages: :boolean

    attribute(:resources) { |page| page[:stats].resources }
    attribute(:languages) { |page| page[:stats].languages }
    attribute(:recitations) { |page| page[:stats].recitations }
    many :categories, source: proc { self[:stats].categories }, resource: CategoryCountResource

    many :samples, resource: SampleResource, source: proc {
      self[:samples].map { |type, resource| { type:, resource:, count: self[:stats].per_type.fetch(type, 0) } }
    }
    # Each tab's preview is left out of the first response and loaded when its tab opens. A type
    # with no sample has none.
    PREVIEWS.each do |type, serializer|
      name = :"#{type.underscore}_preview"
      typelize name => "#{serializer} | Previews::UnavailableResource | null"
      attribute(name, inertia: :optional) { |page| page[:samples][type]&.then { Previews.as_json(Previews.for(_1)) } }
    end

    many :showcase, resource: AppResource
    attribute(:apps_count) { |page| page[:apps].size }
    many :tools, resource: SiteNavLinkResource
    # The guided setup's goals and the first starter kits, while the `start` group serves them;
    # otherwise none, and the hero and closing buttons keep their catalog links.
    many :goals, source: proc { PageGroups.enabled?(:start) ? GuidedSetup::GOALS.values : [] },
                 resource: Start::GoalResource
    many :kits, resource: Start::KitCardResource
    # Whether the catalog, the apps directory and the tools overview are new pages (Inertia
    # visits) or old pages; with the `apps` group off there is no apps directory, and with
    # `start` off no guided setup or kits.
    attribute(:catalog_pages) { PageGroups.enabled?(:catalog) }
    attribute(:apps_page) { PageGroups.enabled?(:apps) }
    attribute(:content_pages) { PageGroups.enabled?(:content) }
    attribute(:start_pages) { PageGroups.enabled?(:start) }
  end
end
