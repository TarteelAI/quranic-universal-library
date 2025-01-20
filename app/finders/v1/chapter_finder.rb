module V1
  class ChapterFinder < BaseFinder
    def chapter(id_or_slug)
      chapters(filters: false).find_using_slug(id_or_slug)
    end

    def chapters(filters: true)
      scope = eager_load_names(
        Chapter.order('chapters.id asc'),
        locale: params[:locale]
      )

      if filters
        scope = filter_by_name(params[:name], scope) if params[:name].present?
        scope = filter_by_revelation_place(params[:revelation_place], scope) if params[:revelation_place].present?
      end

      scope
    end

    protected

    def filter_by_name(name, chapters)
      chapters.where("name_simple ILIKE ?", "%#{name}%")
    end

    def filter_by_revelation_place(revelation_place, chapters)
      chapters.where(revelation_place: revelation_place)
    end

    def eager_load_names(chapters, locale: 'en')
      language = Language.find_with_id_or_iso_code(locale)
      chapters = chapters.includes(:translated_name)

      with_default_names = chapters
                             .where(
                               translated_names: { language_id: Language.default.id }
                             )

      chapters = if language.nil? || language.english?
                   with_default_names
                 else
                   chapters
                     .where(translated_names: { language_id: language.id })
                     .or(with_default_names)
                 end

      chapters.order('translated_names.language_priority DESC')
    end
  end
end