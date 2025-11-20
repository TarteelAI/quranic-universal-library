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

    def get_translated_name(resource)
      # Use the translated_name_cache and locale loaded from SQL subquery
      translated_name = resource.read_attribute(:translated_name_cache)
      translated_name_locale = resource.read_attribute(:translated_name_locale_cache)

      if translated_name.present?
        {
          name: translated_name,
          locale: translated_name_locale
        }
      else
        {
          name: resource.name,
          locale: 'en'
        }
      end
    end

    private

    def process_results(records, resource_type: ResourceContent)
      records = apply_language_filter(records, resource_type: resource_type)
      eager_load_best_names(records, resource_type: resource_type)
    end

    def eager_load_best_names(resources, resource_type: ResourceContent)
      requested_language = requested_language_for_translated_name
      default_lang = Language.default

      # Using LEFT JOIN to include resources without translated names
      language_ids = if requested_language.nil? || requested_language.english?
                       [default_lang.id]
                     else
                       [requested_language.id, default_lang.id]
                     end

      # Join with languages table to get iso_code directly
      best_name_subquery = TranslatedName
                             .joins(:language)
                             .select(
                               'DISTINCT ON (translated_names.resource_id) translated_names.resource_id',
                               'translated_names.name',
                               'translated_names.language_id',
                               'languages.iso_code AS language_iso_code',
                               'translated_names.language_priority'
                             )
                             .where(resource_type: resource_type.to_s, language_id: language_ids)
                             .order('translated_names.resource_id, translated_names.language_priority DESC')
                             .to_sql

      resources
        .joins("LEFT JOIN (#{best_name_subquery}) AS best_translated_names ON #{resource_type.table_name}.id = best_translated_names.resource_id")
        .select("#{resource_type.table_name}.*, best_translated_names.name AS translated_name_cache, best_translated_names.language_iso_code AS translated_name_locale_cache")
    end

    def requested_language_for_translated_name
      language_code = params[:locale].presence || params[:language].presence
      return nil unless language_code

      @requested_language ||= Language.find_by(iso_code: language_code)
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

