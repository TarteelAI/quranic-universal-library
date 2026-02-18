module V1
  class ResourcesPresenter < ApiPresenter
    def translations
      list = ResourceContent
               .translations
               .approved
               .one_verse
               .order(priority: :asc, id: :asc)

      process_results(list)
    end

    def word_translations
      list = ResourceContent
               .translations
               .approved
               .one_word
               .order(priority: :asc, id: :asc)

      process_results(list)
    end

    def tafsirs
      list = ResourceContent
               .tafsirs
               .approved
               .order(priority: :asc, id: :asc)

      process_results(list)
    end

    def languages
      translation_counts = ResourceContent
                             .translations
                             .approved
                             .group(:language_id)
                             .count

      tafsir_counts = ResourceContent
                        .tafsirs
                        .approved
                        .group(:language_id)
                        .count

      language_ids = (translation_counts.keys + tafsir_counts.keys).uniq

      list = Language
               .where(id: language_ids)
               .order(:id)

      languages = process_results(list, resource_type: Language)

      languages.map do |language|
        {
          id: language.id,
          name: language.name,
          iso_code: language.iso_code,
          native_name: language.native_name,
          direction: language.direction,
          translated_name: get_translated_name(language),
          translations_count: translation_counts[language.id] || 0,
          tafsirs_count: tafsir_counts[language.id] || 0
        }
      end
    end

    private

    def process_results(records, resource_type: ResourceContent)
      records = apply_language_filter(records, resource_type: resource_type)
      eager_load_best_names(records, resource_type: resource_type)
    end

    def apply_language_filter(resources, resource_type:)
      filter_language_code = params[:language].presence

      if filter_language_code.present? && filter_language = Language.find_by(iso_code: filter_language_code)
        if resource_type == Language
          resources.where(id: filter_language.id)
        else
          resources.where(language_id: filter_language.id)
        end
      else
        resources
      end
    end
  end
end

