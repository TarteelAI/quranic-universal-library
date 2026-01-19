module V1
  class TafsirFinder < BaseFinder
    attr_reader :resource_content_id

    def initialize(resource_content_id: nil, locale: nil, current_page: 1, per_page: 20)
      @resource_content_id = resource_content_id
      super(locale: locale, current_page: current_page, per_page: per_page)
    end

    def for_ayah(ayah_key:, language_code: nil, resource_content_ids: [])
      verse = Verse.find_by(verse_key: ayah_key.to_s)
      raise ::Api::RecordNotFound.new("Ayah #{ayah_key} not found") unless verse

      verse_id = verse.id

      approved_resources = approved_tafsir_resources

      if language_code.present?
        language = Language.find_with_id_or_iso_code(language_code)
        raise ::Api::RecordNotFound.new("Language with code/ID #{language_code} not found") unless language
        approved_resources = approved_resources.where(language_id: language.id)
      end

      if resource_content_ids.present?
        approved_resources = approved_resources.where(id: resource_content_ids)
      end

      return Tafsir.none if approved_resources.empty?

      Tafsir
        .where(archived: false)
        .where(resource_content_id: approved_resources.pluck(:id))
        .where('start_verse_id <= ? AND end_verse_id >= ?', verse_id, verse_id)
        .order(:verse_id)
    end

    def for_ayahs(verse_ids)
      return Tafsir.none if verse_ids.empty?

      min_verse_id = verse_ids.min
      max_verse_id = verse_ids.max

      Tafsir
        .where(archived: false)
        .where(resource_content_id: @resource_content_id)
        .where('start_verse_id <= ? AND end_verse_id >= ?', max_verse_id, min_verse_id)
        .order(Arel.sql("array_position(ARRAY[#{verse_ids.join(',')}], start_verse_id)"))
    end

    protected

    def approved_tafsir_resources
      ResourceContent.tafsirs.approved
    end
  end
end

