# frozen_string_literal: true

module Utils
  class LokaliseSync
    attr_reader :client

    def initialize
      require 'ruby-lokalise-api'

      @client = Lokalise.client(
        ENV['LOKALISE_API_KEY'],
        enable_compression: true,
        open_timeout: 50,
        timeout: 500
      )
    end

    def import_new_keys
      download_language_names
      download_translation_names
      download_tafsir_names
      download_author_names
    end

    def export_new_keys
      # TODO
    end

    def upload_tafsir_names
      language_keys = existing_language_keys
      ResourceContent.tafsirs
                     .includes(translated_names: :language)
                     .find_in_batches(batch_size: 50) do |batch|
        data = prepare_tafsir_names(batch, language_keys)

        client.create_keys(
          project_id,
          data
        )
      end
    end

    def upload_translation_names
      language_keys = existing_language_keys
      ResourceContent.translations.one_verse
                     .includes(translated_names: :language)
                     .find_in_batches(batch_size: 50) do |batch|
        data = prepare_translation_names(batch, language_keys)

        client.create_keys(
          project_id,
          data
        )
      end
    end

    def upload_author_names
      language_keys = existing_language_keys
      Author.where.not(id: 1)
            .includes(:resource_contents, translated_names: :language)
            .find_in_batches(batch_size: 50) do |batch|
        data = prepare_author_names(batch, language_keys)

        client.create_keys(
          project_id,
          data
        )
      end
    end

    def upload_language_names
      language_keys = existing_language_keys

      Language.find_in_batches(batch_size: 50) do |batch|
        data = prepare_language_names(batch, language_keys)

        client.create_keys(
          project_id,
          data
        )
      end
    end

    def remove_author_names
      remove_keys_for_tag 'author'
    end

    def remove_translation_names
      remove_keys_for_tag 'translation'
    end

    def remove_tafsir_names
      remove_keys_for_tag 'tafsir'
    end

    def download_language_names
      keys = get_keys_for_tag('language', include_translations: 1)
      keys.each do |key|
        language = Language.find(key.key_name['other'][/\d+/])

        key.translations.each do |translation|
          next unless (translation['words']).positive? && translation['is_reviewed']

          lang = Language.find_by(iso_code: translation['language_iso'])

          translated_name = language.translated_names.where(language: lang).first_or_initialize
          translated_name.name = translation['translation']
          translated_name.save(validate: false)
        end
      end
    end

    def download_translation_names
      keys = get_keys_for_tag('translation', include_translations: 1)

      keys.each do |key|
        resource = ResourceContent.find(key.key_name['other'][/\d+/])
        puts "Importing names for #{resource.id}"

        key.translations.each do |translation|
          next unless (translation['words']).positive? && translation['is_reviewed']

          lang = Language.find_by(iso_code: translation['language_iso'])

          translated_name = resource.translated_names.where(language: lang).first_or_initialize
          translated_name.name = translation['translation']
          translated_name.save(validate: false)
        end
      end
    end

    def download_tafsir_names
      keys = get_keys_for_tag('tafsir', include_translations: 1)
      keys.each do |key|
        resource = ResourceContent.find(key.key_name['other'][/\d+/])

        key.translations.each do |translation|
          next unless (translation['words']).positive? && translation['is_reviewed']

          lang = Language.find_by(iso_code: translation['language_iso'])

          translated_name = resource.translated_names.where(language: lang).first_or_initialize
          translated_name.name = translation['translation']
          translated_name.save(validate: false)
        end
      end
    end

    def download_author_names
      keys = get_keys_for_tag('author', include_translations: 1)
      keys.each do |key|
        author = Author.find(key.key_name['other'][/\d+/])

        key.translations.each do |translation|
          next unless (translation['words']).positive? && translation['is_reviewed']

          lang = Language.find_by(iso_code: translation['language_iso'])

          translated_name = author.translated_names.where(language: lang).first_or_initialize
          translated_name.name = translation['translation']
          translated_name.save(validate: false)
        end
      end
    end

    def upload_system_languages
      data = prepare_project_languages_data

      if data.present?
        response = client.create_languages(
          project_id,
          data
        )

        puts { "#{response.collection.size} language created" }
      else
        puts 'No new language to create'
      end
    end

    protected

    def get_keys_for_tag(tag, include_translations: 0)
      page = 1
      keys = []
      response = client.keys(
        project_id,
        limit: 500,
        page: page,
        include_translations: include_translations,
        filter_tags: tag
      )

      while response.collection.size.positive?
        response.collection.each do |key|
          keys << key
        end

        page += 1
        response = client.keys(
          project_id,
          limit: 500,
          page: page,
          include_translations: include_translations,
          filter_tags: tag
        )
      end

      keys
    end

    def project_id
      ENV['LOKALISE_PROJECT_ID']
    end

    def remove_keys_for_tag(tag)
      page = 1
      response = client.keys(project_id, limit: 500, page: page)

      while response.collection.size.positive?
        keys_to_remove = []
        response.collection.each do |key|
          keys_to_remove << key.key_id if key.key_name['other'].start_with?("#{tag}:")
        end

        client.destroy_keys(project_id, keys_to_remove) if keys_to_remove.present?

        page += 1
        response = client.keys(project_id, limit: 500, page: page)
      end
    end

    def prepare_project_languages_data
      translated_name_languages = TranslatedName.select('DISTINCT language_id').map(&:language_id)
      translation_languages = Translation.select('DISTINCT language_id').map(&:language_id)
      tafsir_languages = Tafsir.select('DISTINCT language_id').map(&:language_id)
      all_languages = (translated_name_languages + translation_languages + tafsir_languages).uniq

      languages = Language
                    .where(id: all_languages)
                    .where.not(iso_code: existing_language_keys)

      languages.map do |lang|
        { lang_iso: lang.iso_code, custom_iso: lang.iso_code, custom_name: lang.name }
      end
    end

    def existing_language_keys
      response = client.project_languages(project_id, limit: 200)

      response.collection.map(&:lang_iso)
    end

    def prepare_tafsir_names(records, valid_languages)
      data = records.map do |tafsir|
        translations = tafsir.translated_names.map do |translated_name|
          iso_code = translated_name.language.iso_code

          next unless valid_languages.include?(iso_code)

          {
            language_iso: iso_code,
            translation: translated_name.name.to_s.strip
          }
        end.compact_blank

        next if translations.blank?

        key = "tafsir:#{tafsir.id}-#{tafsir.name.to_s.strip.first(20).parameterize}"

        {
          key_name: key,
          platforms: %w[web],
          translations: translations,
          comments: [
            { comment: "Language: #{tafsir.language_name.humanize}" }
          ],
          tags: ['tafsir']
        }
      end

      data.compact_blank
    end

    def prepare_translation_names(records, valid_languages)
      data = records.map do |translation|
        translations = translation.translated_names.map do |translated_name|
          iso_code = translated_name.language.iso_code

          next unless valid_languages.include?(iso_code)

          {
            language_iso: iso_code,
            translation: translated_name.name.to_s.strip
          }
        end.compact_blank

        next if translations.blank?

        key = "translation:#{translation.id}-#{translation.name.to_s.strip.first(20).parameterize}"

        {
          key_name: key,
          platforms: %w[web],
          translations: translations,
          comments: [
            { comment: "Language: #{translation.language_name.humanize}" }
          ],
          tags: ['translation']
        }
      end

      data.compact_blank
    end

    def prepare_language_names(records, valid_languages)
      data = records.map do |language|
        translations = language.translated_names.map do |translated_name|
          iso_code = translated_name.language.iso_code

          next unless valid_languages.include?(iso_code)

          {
            language_iso: iso_code,
            translation: translated_name.name.to_s.strip
          }
        end.compact_blank

        next if translations.blank?

        key = "language:#{language.id}-#{language.name.to_s.strip.first(20).parameterize}"

        {
          key_name: key,
          platforms: %w[web],
          translations: translations,
          tags: ['language']
        }
      end

      data.compact_blank
    end

    def prepare_author_names(records, valid_languages)
      data = records.map do |author|
        translations = author.translated_names.map do |translated_name|
          iso_code = translated_name.language.iso_code

          next unless valid_languages.include?(iso_code)

          {
            language_iso: iso_code,
            translation: translated_name.name.to_s.strip
          }
        end.compact_blank

        next if translations.blank?

        resources = author.resource_contents.where(sub_type: %w[translation tafsir audio])
        comments = resources.map do |resource|
          { comment: "#{resource.name.strip} - (#{resource.sub_type}) in #{resource.language_name.humanize}" }
        end

        key = "author:#{author.id}-#{author.name.to_s.strip.first(20).parameterize}"

        {
          key_name: key,
          comments: comments,
          platforms: %w[web],
          translations: translations,
          tags: ['author']
        }
      end

      data.compact_blank
    end
  end
end
