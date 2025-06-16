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
          last_updated = resource.meta_value('quranenc_last_updated')

          if last_updated.nil? || last_updated.to_i != version[:last_update].to_i
            report_update_translation(version, resource)
          end
        else
          report_new_translation(version, importer)
        end
      end
    end

    def report_update_translation(version, resource)
      resource.set_meta_value("source", 'quranenc')
      resource.set_meta_value("version_on_quran_enc", version[:version])
      resource.set_meta_value("updated_timestamp_on_quran_enc", version[:last_update].to_i)
      resource.set_meta_value("updated_date_on_quran_enc", version[:last_update].strftime('%B %d, %Y at %I:%M %P %Z'))
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
      resource = ResourceContent.where("meta_data ->> 'quranenc-key' = '#{key}'").first_or_initialize

      if translation = importer.get_translation_for_key(key)
        language = Language.find_by(iso_code: translation['language_iso_code'])

        title = resource.name.presence || translation['title'] || key.humanize

        resource.name = title
        resource.language ||= language
        resource.cardinality_type = ResourceContent::CardinalityType::OneVerse
        resource.sub_type = ResourceContent::SubType::Translation
      else
        resource.name = version[:name]
      end

      resource.resource_type_name = ResourceContent::ResourceType::Content
      resource.set_meta_value("source", 'quranenc')
      resource.set_meta_value("quranenc-key", key)
      resource.set_meta_value("version-on-quran-enc", version[:version])
      resource.set_meta_value("updated-timestamp-on-quran_enc", version[:last_update])
      resource.set_meta_value("updated-date-on-quran-enc", version[:last_update].strftime('%B %d, %Y at %I:%M %P %Z'))
      resource.save(validate: false)

      todo = AdminTodo.where(
        resource_content_id: resource.id,
        is_finished: false,
        tags: 'new-resource'
      ).first_or_initialize

      todo.description = "New translation/tafsir is available on QuranEcn.
                   \n Name: <strong>#{resource.name}</strong>(##{resource.id}).
                   \n Key: #{version[:key]}
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
    end

    def lookup_resource_content(quranenc_key)
      ResourceContent.where("meta_data ->> 'quranenc-key' = '#{quranenc_key}'").first
    end
  end
end
