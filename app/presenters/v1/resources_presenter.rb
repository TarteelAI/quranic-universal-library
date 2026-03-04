module V1
  class ResourcesPresenter < ApiPresenter
    def translations
      list = ResourceContent
               .translations
               .approved
               .one_verse
               .includes(:language)
               .order(priority: :asc, id: :asc)

      process_results(list).select { |resource| translation_resource_usable?(resource) }
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
               .includes(:language)
               .order(priority: :asc, id: :asc)

      process_results(list).select { |resource| tafsir_resource_usable?(resource) }
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

    def translation_resource_usable?(resource)
      slug = resource.slug.to_s.strip
      return false if slug.blank?

      language_code = resource.language&.iso_code.to_s.strip.downcase
      return false if language_code.blank?

      slug_matches_language?(slug, language_code)
    end

    def tafsir_resource_usable?(resource)
      slug = resource.slug.to_s.strip
      return false if slug.blank?

      language_code = resource.language&.iso_code.to_s.strip.downcase
      return false if language_code.blank?
      return false if resource.records_count.to_i <= 0

      slug_matches_language?(slug, language_code)
    end

    def slug_matches_language?(slug, language_code)
      normalized_slug = slug.to_s.downcase.strip
      return false if normalized_slug.blank?
      return false if language_code.blank?

      if normalized_slug.start_with?('quran.')
        return normalized_slug.include?(".#{language_code}.")
      end

      prefix = normalized_slug[/\A([a-z]{2,3})(?:[-_\.])/, 1]
      return true if prefix.blank?

      prefix == language_code
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

