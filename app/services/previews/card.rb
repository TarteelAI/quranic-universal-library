# frozen_string_literal: true

module Previews
  # A resource's preview at card size, for the resource cards of the catalog and type pages.
  #
  # It is the detail page's preview (Previews.for) of the start of the Quran, cut to what a card
  # shows: a layout's first page, a recitation's Al-Fatihah track, and ayah 1:2 in a script or
  # with a translation. The page fetches it per card once the card is on screen
  # (Catalog::PreviewsController), so the catalog's first response carries only each card's
  # `preview_kind`. A type without a kind here keeps the card without a preview.
  module Card
    QUERY = { 'page' => '1', 'surah' => '1', 'from' => '2', 'to' => '2' }.freeze

    KINDS = {
      'mushaf-layout' => 'layout',
      'recitation' => 'recitation',
      'quran-script' => 'script',
      'translation' => 'text'
    }.freeze

    SERIALIZERS = {
      MushafLayout::Preview => CardLayoutResource,
      Recitation::Preview => CardRecitationResource,
      Script::Preview => CardScriptResource,
      Text::Preview => CardTextResource
    }.freeze

    def self.kind(type)
      KINDS[type]
    end

    # The card preview props, or nil when the type has no card preview or this resource cannot
    # be shown (Previews::Unavailable).
    def self.for(resource)
      return unless kind(resource.resource_type)

      preview = Previews.for(resource, QUERY)
      SERIALIZERS[preview.class]&.new(preview)&.serializable_hash
    end
  end
end
