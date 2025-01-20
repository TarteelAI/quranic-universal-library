module V1
  class VersePresenter < BasePresenter
    delegate :include_words?, to: :finder

    def verses
      @pagination, records = pagy(finder.verses(@filters))
      records
    end

    def chapter
      finder.chapter(params[:id]) || invalid_chapter(params[:id])
    end

    def set_filters(filters)
      @filters = filters
    end

    def finder
      @finder ||= ::V1::VerseFinder.new(params)
    end

    def allowed_fields
      [
        "chapter_id",
        "verse_number",
        "text_uthmani",
        "text_indopak",
        "text_imlaei_simple",
        "juz_number",
        "hizb_number",
        "rub_el_hizb_number",
        "sajdah_type",
        "sajdah_number",
        "image_url",
        "text_imlaei",
        "text_uthmani_simple",
        "text_uthmani_tajweed",
        "code_v1",
        "code_v2",
        "text_qpc_hafs",
        "words_count",
        "text_indopak_nastaleeq",
        "text_qpc_nastaleeq",
        "ruku_number",
        "surah_ruku_number",
        "manzil_number",
        "text_qpc_nastaleeq_hafs",
        "text_digital_khatt",
        "text_digital_khatt_v1",
        "text_qpc_hafs_tajweed",
        "text_digital_khatt_indopak"
      ]
    end
  end
end