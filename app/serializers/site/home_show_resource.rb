# frozen_string_literal: true

module Site
  # Props of the home page (Site::HomeController#show): the catalog counts, the contributors, the
  # categories with their counts, the samples of the library cards, the apps of the apps showcase,
  # three contribution tools, the guided setup's goals and the first starter kits, and the links
  # that depend on the page groups.
  class HomeShowResource < ApplicationResource
    # The preview each sampled type's card shows a part of (HomeShowResource.preview), by type.
    PREVIEWS = {
      'recitation' => 'Previews::RecitationResource', 'mushaf-layout' => 'Previews::MushafLayoutResource',
      'quran-script' => 'Site::SampleCardsResource', 'translation' => 'Site::SampleCardsResource',
      'tafsir' => 'Previews::TextResource', 'morphology' => 'Previews::RecordsResource',
      'ayah-topics' => 'Previews::RecordsResource', 'quran-metadata' => 'Previews::RecordsResource',
    }.freeze
    # The languages the translation card goes through.
    LANGUAGES = 6
    # The tafsir card's ayah, the first (its entry often starts by introducing the surah), and the
    # characters of its entry the card receives (Card::TEXT_LIMIT can hold only a heading).
    TAFSIR_QUERY = { 'surah' => '1', 'from' => '1', 'to' => '1' }.freeze
    TAFSIR_LIMIT = 1_000

    # A sample's preview props. Most cards show a part of the detail page's preview of their
    # sample. The script card shows ayah 1:2 in SCRIPTS and the translation card in the sample
    # and the first translations of other languages, each as the catalog's cards show it; the
    # tafsir card the start of the sample's entry for 1:1, without the list of surahs.
    def self.preview(type, resource)
      case type
      when 'quran-script' then cards(script_cards)
      when 'translation' then cards(translation_cards)
      when 'tafsir' then tafsir(resource)
      else Previews.as_json(Previews.for(resource))
      end
    end

    def self.cards(cards) = SampleCardsResource.new({ cards: }).serializable_hash

    def self.script_cards
      Catalog::Samples.new.scripts.filter_map do |label, script|
        Previews::Card.for(script)&.then { { label:, resource: script, preview: _1 } }
      end
    end

    def self.translation_cards
      Previews::Card.translations(Catalog::Samples.new.translations(LANGUAGES)).map do |translation, preview|
        { label: translation.resource_content.language.name, resource: translation, preview: }
      end
    end

    def self.tafsir(resource)
      preview = Previews.for(resource, TAFSIR_QUERY)
      entries = preview.entries.first(1).map do |entry|
        text, truncated = entry.text && Previews.excerpt(entry.text, TAFSIR_LIMIT)
        entry.with(text:, truncated: truncated || entry.truncated)
      end
      Previews.as_json(preview.with(entries:, surahs: []))
    end

    typelize resources: :number, languages: :number, contributors: :number, apps_count: :number,
             catalog_pages: :boolean, apps_page: :boolean, content_pages: :boolean, start_pages: :boolean

    attribute(:resources) { |page| page[:stats].resources }
    attribute(:languages) { |page| page[:stats].languages }
    attribute(:contributors) { |page| page[:contributors].call }
    many :categories, source: proc { self[:stats].categories }, resource: CategoryCountResource

    many :samples, resource: SampleResource,
                   source: proc { self[:samples].map { |type, resource| { type:, resource: } } }
    # Each card's preview is left out of the first response and loaded when the card comes near
    # the screen. A type with no sample has none.
    PREVIEWS.each do |type, serializer|
      name = :"#{type.underscore}_preview"
      typelize name => "#{serializer} | Previews::UnavailableResource | null"
      attribute(name, inertia: :optional) { |page| page[:samples][type]&.then { HomeShowResource.preview(type, _1) } }
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
