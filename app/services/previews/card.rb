# frozen_string_literal: true

module Previews
  # A resource's preview at card size, for the resource cards of the catalog and type pages.
  #
  # It is the detail page's preview (Previews.for) of the start of the Quran, cut to what a card
  # shows: a layout's first page, a recitation's Al-Fatihah track, ayah 1:2 in a script or with
  # its translation, transliteration or tafsir, and a line drawn in a font. The page fetches it
  # per card once the card is on screen (Catalog::PreviewsController), so the catalog's first
  # response carries only each card's `preview_kind`. A type without a kind here (the record
  # types) keeps the card without a preview.
  module Card
    QUERY = { 'page' => '1', 'surah' => '1', 'from' => '2', 'to' => '2' }.freeze
    # Characters of a text entry a card receives: a tafsir entry can run to thousands.
    TEXT_LIMIT = 400

    KINDS = {
      'mushaf-layout' => 'layout',
      'recitation' => 'recitation',
      'quran-script' => 'script',
      'font' => 'font',
      'translation' => 'text',
      'transliteration' => 'text',
      'tafsir' => 'text',
    }.freeze

    SERIALIZERS = {
      MushafLayout::Preview => CardLayoutResource,
      Recitation::Preview => CardRecitationResource,
      Script::Preview => CardScriptResource,
      Font::Preview => CardFontResource,
      Text::Preview => CardTextResource,
    }.freeze

    def self.kind(type)
      KINDS[type]
    end

    # The card preview props, or nil when the type has no card preview or this resource cannot
    # be shown (Previews::Unavailable, a tafsir with no entry for the ayah, or a page font whose
    # page 1 has no words).
    def self.for(resource)
      return unless kind(resource.resource_type)

      preview = Previews.for(resource, QUERY)
      return if empty?(preview)

      SERIALIZERS[preview.class]&.new(preview)&.serializable_hash
    end

    def self.empty?(preview)
      case preview
      when Text::Preview then preview.entries.empty?
      when Font::Preview then preview.page&.lines&.none? { |line| line.words.any? }
      else false
      end
    end
  end
end
