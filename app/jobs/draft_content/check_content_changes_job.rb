# DraftContent::CheckContentChangesJob.perform_now

module DraftContent
  class CheckContentChangesJob < ApplicationJob
    sidekiq_options retry: 1, backtrace: true

    def perform
      importer = Importer::QuranEnc.new

      check_for_updates(importer)
    end

    protected

    def check_for_updates(importer)
      versions = importer.get_change_log

      versions.each do |version|
        if (resource = lookup_resource_content(version[:key]))
          last_updated = last_updated_on_quranenc(resource)

          if last_updated.nil? || last_updated != version[:last_update].to_i
            report_update_translation(version, resource)
            auto_import_draft(resource)
          end
        else
          resource = report_new_translation(version, importer)
          auto_import_draft(resource)
        end
      end
    end

    def auto_import_draft(resource)
      return if resource.blank? || resource.has_draft_translation?

      ImportDraftContentJob.perform_later(resource.id)
    end

    def report_update_translation(version, resource)
      resource.set_meta_value("source", 'quranenc')
      set_quranenc_version_meta(resource, version)
      resource.save

      todo = AdminTodo.where(
        resource_content_id: resource.id,
        is_finished: false,
        tags: 'update-translation'
      ).first_or_initialize

      todo.description = "New update is available on QuranEcn for translation <strong>#{resource.name}</strong>(##{resource.id}).
                   \n  Key: #{version[:key]} Last updated: #{Time.at version[:last_update]}.
                   \n <a href='https://qul.tarteel.ai/cms/resource_contents/#{resource.id}' target='_blank'>View resource in QUL</a>
                   \n <a href='https://qul.tarteel.ai/cms/translations?q%5Bresource_content_id_eq%5D=#{resource.id}&order=id_desc/' target='_blank'>View resource translations in QUL</a>
                   \n <a href='https://quranenc.com/en/browse/#{version[:key]}/' target='_blank'>View translation on QuranEnc</a>"

      todo.save(validate: false)

      ActiveAdmin::Comment.create(
        namespace: 'cms',
        resource: todo,
        author_type: 'User',
        author_id: 1,
        body: "<a href='https://quranenc.com/en/browse/#{version[:key]}/' target='_blank'>View translation on QuranEnc</a>"
      )
    end

    def report_new_translation(version, importer)
      key = version[:key]
      resource = lookup_resource_content(key) || ResourceContent.new
      translation = importer.get_translation_for_key(key)
      tafsir = tafsir_key?(key)

      language = resource.language || Language.find_by(iso_code: translation&.dig('language_iso_code'))

      resource.name = resource.name.presence ||
                      translation&.dig('title').presence ||
                      version[:name].presence ||
                      key.humanize

      if language
        resource.language = language
        resource.language_name = language.name.downcase
      end

      resource.resource_info = resource.resource_info.presence || translation&.dig('description').presence
      resource.data_source ||= quranenc_data_source
      resource.resource_type = ResourceContent::ResourceType::Content
      resource.resource_type_name = ResourceContent::ResourceType::Content

      if tafsir
        resource.sub_type = ResourceContent::SubType::Tafsir
        resource.cardinality_type = ResourceContent::CardinalityType::NVerse
      else
        resource.sub_type = ResourceContent::SubType::Translation
        resource.cardinality_type = ResourceContent::CardinalityType::OneVerse
      end

      resource.approved = false if resource.new_record?

      resource.set_meta_value("source", 'quranenc')
      resource.set_meta_value("quranenc-key", key)
      set_quranenc_version_meta(resource, version)
      resource.save(validate: false)

      todo = AdminTodo.where(
        resource_content_id: resource.id,
        is_finished: false,
        tags: 'new-resource'
      ).first_or_initialize

      missing_language_warning = language ? '' : "\n <strong>Language could not be detected#{" for iso code #{translation['language_iso_code']}" if translation&.dig('language_iso_code')}. Set it manually, draft import is skipped until then.</strong>"

      todo.description = "New translation/tafsir is available on QuranEcn.
                   \n Name: <strong>#{resource.name}</strong>(##{resource.id}).
                   \n Key: #{version[:key]}#{missing_language_warning}
                   \n <a href='https://qul.tarteel.ai/cms/resource_contents/#{resource.id}' target='_blank'>View resource in QUL</a>
                   \n <a href='https://qul.tarteel.ai/cms/translations?q%5Bresource_content_id_eq%5D=#{resource.id}&order=id_desc/' target='_blank'>View resource translations in QUL</a>
                   \n <a href='https://quranenc.com/en/browse/#{version[:key]}/' target='_blank'>View translation on QuranEnc</a>"

      todo.save

      ActiveAdmin::Comment.create(
        namespace: 'cms',
        resource: todo,
        author_type: 'User',
        author_id: 1,
        body: "<a href='https://quranenc.com/en/browse/#{key}/' target='_blank'>View translation on QuranEnc</a>"
      )

      resource
    end

    def lookup_resource_content(quranenc_key)
      ResourceContent.where("meta_data ->> 'quranenc-key' = ?", quranenc_key).first
    end

    QURANENC_VERSION_KEY = 'quranenc-version'
    QURANENC_LAST_UPDATED_KEY = 'quranenc-last-updated'
    QURANENC_LAST_UPDATED_DATE_KEY = 'quranenc-last-updated-date'

    def set_quranenc_version_meta(resource, version)
      resource.set_meta_value(QURANENC_VERSION_KEY, version[:version])
      resource.set_meta_value(QURANENC_LAST_UPDATED_KEY, version[:last_update].to_i)
      resource.set_meta_value(QURANENC_LAST_UPDATED_DATE_KEY, version[:last_update].strftime('%B %d, %Y at %I:%M %P %Z'))
    end

    def last_updated_on_quranenc(resource)
      value = resource.meta_value(QURANENC_LAST_UPDATED_KEY)

      value && value.to_i
    end

    def tafsir_key?(quranenc_key)
      Importer::QuranEncTafsir::TAFSIR_MAPPING.key?(quranenc_key.to_sym)
    end

    def quranenc_data_source
      @quranenc_data_source ||= DataSource.find(14)
    end
  end
end
