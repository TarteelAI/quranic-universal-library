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

    # The `v` of the preview URL a card fetches: a digest of the build and of the rows an editor
    # changes (the resource and its content row), so a shared cache can keep a preview for long
    # and an edit or a deploy shows on the next page load (DECISIONS.md). The other content rows
    # a preview reads (words, texts, audio files) are not in it. Nil for a type without a card
    # preview.
    def self.version(resource)
      return unless kind(resource.resource_type)

      times = [resource.updated_at, resource.resource_content&.updated_at].map { |time| time&.iso8601(6) }
      Digest::SHA256.hexdigest([build, *times].join('|'))[0, 12]
    end

    # The deployed commit where the image names one (GIT_SHA), else the frontend's digest.
    def self.build
      @build ||= ENV['GIT_SHA'].presence || ViteRuby.digest
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

    # [resource, props] for each ayah-by-ayah translation that has the card's ayah, read in two
    # queries rather than a preview each: the home page's translation card shows the ayah in
    # several. Preload each resource's content and language.
    def self.translations(resources)
      verse = Verse.select(:id, :verse_key, :verse_number, :text_uthmani)
        .find_by!(chapter_id: QUERY['surah'].to_i, verse_number: QUERY['from'].to_i)
      texts = Translation.where(verse_id: verse.id, resource_content_id: resources.map(&:resource_content_id))
        .pluck(:resource_content_id, :text).to_h
      resources.filter_map do |resource|
        text = texts[resource.resource_content_id] or next
        [resource, CardTextResource.new(text_preview(verse, resource, text)).serializable_hash]
      end
    end

    # A Previews::Text preview of one ayah-by-ayah entry, as Previews::Text builds it.
    def self.text_preview(verse, resource, text)
      ayah = Text::AyahText.new(key: verse.verse_key, text: verse.text_uthmani)
      entry = Text::Entry.new(key: verse.verse_key, ayahs: [ayah], text: Previews.sanitize(text), truncated: false,
                              footnotes: [], words: [],)
      Text::Preview.new(granularity: 'ayah', locale: Previews.locale(resource.resource_content, 'und'), surah: nil,
                        surahs: [], from: verse.verse_number, to: verse.verse_number, entries: [entry],)
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
