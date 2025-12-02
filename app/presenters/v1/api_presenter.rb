module V1
  class ApiPresenter < ApplicationPresenter
    def get_translated_name(resource)
      cached_name = @translated_names_cache[resource.id] || {}

      if cached_name.present?
        {
          name: cached_name[:name],
          locale: cached_name[:locale]
        }
      else
        {
          name: resource.name,
          locale: 'en'
        }
      end
    end

    protected
    def filter_chapter
      chapter = (params[:chapter] ||
      params[:chapter_id] ||
      params[:surah_number] ||
      params[:chapter_number])

      return nil unless chapter.present?

      chapter.to_i.abs
    end

    def eager_load_best_names(resources, resource_type: ResourceContent)
      requested_language = requested_language_for_translated_name
      default_lang = Language.default

      language_ids = if requested_language.nil? || requested_language.english?
                       [default_lang.id]
                     else
                       [requested_language.id, default_lang.id]
                     end

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

      with_names = resources
                     .joins("LEFT JOIN (#{best_name_subquery}) AS best_translated_names ON #{resource_type.table_name}.id = best_translated_names.resource_id")
                     .select("#{resource_type.table_name}.*, best_translated_names.name AS translated_name_cache, best_translated_names.language_iso_code AS translated_name_locale_cache")

      with_names.each do |resource|
        @translated_names_cache[resource.id] = {
          name: resource.read_attribute(:translated_name_cache),
          locale: resource.read_attribute(:translated_name_locale_cache)
        }
      end

      with_names
    end

    def requested_language_for_translated_name
      language_code = api_locale
      return nil unless language_code

      @requested_language ||= Language.find_by(iso_code: language_code)
    end

    def api_locale
      locale = params[:locale].presence || 'en'

      if available_locales.include?(locale)
        locale
      else
        'en'
      end
    end

    def available_locales
      @locales ||= Language.where(id: TranslatedName.pluck(:language_id).uniq).pluck(:iso_code)
    end

    def invalid_chapter(value)
      raise_invalid_id_error(value, "Chapter", "1-114")
    end

    def invalid_juz(value)
      raise_invalid_id_error(value, "Juz", "1-30")
    end

    def invalid_manzil(value)
      raise_invalid_id_error(value, "Manzil", "1-7")
    end

    def invalid_hizb(value)
      raise_invalid_id_error(value, "Hizb", "1-60")
    end

    def invalid_rub_el_hizb(value)
      raise_invalid_id_error(value, "Rub el Hizb", "1-240")
    end

    def invalid_mushaf_page(value, max_page = 604)
      raise_invalid_id_error(value, "Mushaf Page", "1-#{max_page}")
    end

    def invalid_ruku(value)
      raise_invalid_id_error(value, "Ruku", "1-558")
    end

    def raise_invalid_id_error(invalid_value, resource_type, range)
      raise ::Api::RecordNotFound.new("#{invalid_value} #{resource_type} ID or slug is invalid. Please select a valid slug or #{resource_type} ID from #{range}.")
    end
  end
end