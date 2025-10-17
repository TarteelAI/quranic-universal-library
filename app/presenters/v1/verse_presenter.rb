module V1
  class VersePresenter < ApplicationPresenter
    VERSE_FIELDS = [
      'text_uthmani',
      'text_indopak',
      'text_imlaei_simple',
      'juz_number',
      'hizb_number',
      'rub_el_hizb_number',
      'sajdah_type',
      'sajdah_number',
      'image_url',
      'text_imlaei',
      'text_uthmani_simple',
      'text_uthmani_tajweed',
      'code_v1',
      'code_v2',
      'v2_page',
      'text_qpc_hafs',
      'words_count',
      'text_indopak_nastaleeq',
      'text_qpc_nastaleeq',
      'ruku_number',
      'surah_ruku_number',
      'manzil_number',
      'text_qpc_nastaleeq_hafs',
      'text_digital_khatt',
      'text_digital_khatt_v1',
      'text_qpc_hafs_tajweed',
      'text_digital_khatt_indopak'
    ].freeze

    WORD_FIELDS = [
      'text_uthmani',
      'text_indopak',
      'text_imlaei_simple',
      'audio_url',
      'image_url',
      'location',
      'text_imlaei',
      'text_uthmani_simple',
      'text_uthmani_tajweed',
      'en_transliteration',
      'code_v1',
      'code_v2',
      'text_qpc_hafs',
      'text_indopak_nastaleeq',
      'text_qpc_nastaleeq',
      'text_qpc_nastaleeq_hafs',
      'text_digital_khatt',
      'text_digital_khatt_v1',
      'text_qpc_hafs_tajweed',
      'text_digital_khatt_indopak'
    ]

    def verses
      filters = {
        filter: params[:filter].to_s.strip.downcase,
        filter_id: params[:id],
        words: render_words?,
        mushaf_id: mushaf_id,
        translations: ayah_translation_ids
      }

      if render_word_translation?
        filters[:word_translation_language] = word_translation_language
      end

      if lookahead.selects?(:from)
        filters[:range] = [
          params[:from].to_i,
          (params[:to] || params[:from].to_i + per_page).to_i
        ]
      end

      list = finder.verses(
        **filters
      )
      @pagination = finder.pagination

      list
    end

    def select2
      list = filter(Verse.order('verse_index ASC'))

      @pagination, list = pagy(list)

      list
    end

    def render_translations?
      ayah_translation_ids.present?
    end

    def render_words?
      lookahead.selects?(:words)
    end

    def render_word_translation?
      lookahead.selects?(:word_translation_language) && word_translation_language
    end

    def word_translation_language
      lang = params[:word_translation_language].presence
      word_translations = ResourceContent.translations.one_word.approved
      language = Language
                   .where(iso_code: lang, id: word_translations.pluck(:language_id))
                   .first
      language&.id
    end

    def verse_fields
      fields = params[:fields].to_s.strip
      return [] if fields.empty?

      fields.split(',') & VERSE_FIELDS
    end

    def word_fields
      fields = params[:word_fields].to_s.strip
      return [] if fields.empty?

      fields.split(',') & WORD_FIELDS
    end

    protected
    def finder
      @finder ||= VerseFinder.new(
        locale: api_locale,
        current_page: current_page,
        per_page: per_page,
      )
    end

    def ayah_translation_ids
      if params[:translations].present?
        # Allow max 10 translation
        # TODO: add translation access rules etc
        params[:translations].split(',').map(&:to_i).first(10)
      else
        []
      end
    end

    def filter(list)
      query = params[:query].to_s.strip

      if query.present?
        list.where("verse_key ILIKE :query", query: "%#{query}%")
      else
        list
      end
    end

    def per_page
      items = params[:per_page].to_i.abs
      [items | 10, 286].min
    end
  end
end