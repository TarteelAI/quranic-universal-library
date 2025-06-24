module V1
  class ChapterFinder < BaseFinder
    def chapter(id_or_slug)
      chapters.find_using_slug(id_or_slug)
    end

    def chapters
      list = Chapter.order(:id).includes(:translated_name)
      eager_load_best_names(list)
    end

    protected
    def eager_load_best_names(chapters)
      language = Language.find_with_id_or_iso_code(locale)
      default_lang = Language.default

      if language.nil? || language.english?
        chapters.joins(:translated_name)
                .where(translated_names: { language_id: default_lang.id })
      else
        # Prefer requested language but fallback to English
        chapters.joins(:translated_name)
                .where(translated_names: {
                  language_id: [language.id, default_lang.id]
                })
                .order('translated_names.language_priority DESC')
      end
    end
  end
end