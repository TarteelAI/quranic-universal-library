class QuranEnc::UpdatesCheckerJob < ApplicationJob
  include Sidekiq::Status::Worker
  sidekiq_options retry: 1, backtrace: true

  def perform
    check_for_updates
  end

  protected

  def importer
    @importer ||= Importer::QuranEnc.new
  end

  def check_for_updates
    versions = fetch_translation_versions

    versions.each do |version|
      if (resource = lookup_resource_content(version['key']))
        last_updated = resource.meta_value('quranenc_last_updated')

        if last_updated.nil? || last_updated.to_i != version['last_update'].to_i
          report_update_translation(version, resource)
        end
      else
        report_new_translation(version)
      end
    end
  end

  def report_update_translation(version, resource)
    resource.set_meta_value("source", 'quranenc')
    resource.set_meta_value("version_on_quran_enc", version['version'])
    resource.set_meta_value("updated_timestamp_on_quran_enc", version['last_update'])
    resource.set_meta_value("updated_date_on_quran_enc", Time.at(version['last_update']).strftime('%B %d, %Y at %I:%M %P %Z'))
    resource.save

    todo = AdminTodo.where(
      resource_content_id: resource.id,
      is_finished: false,
      tags: 'update-translation'
    ).first_or_initialize

    todo.description = "New update is available on QuranEcn for translation <strong>#{resource.name}</strong>(##{resource.id}).
                   \n  Key: #{version['key']} Last updated: #{Time.at version['last_update']}.
                   \n <a href='https://qul.tarteel.ai/admin/resource_contents/#{resource.id}' target='_blank'>View resource in QUL</a>
                   \n <a href='https://qul.tarteel.ai/admin/translations?q%5Bresource_content_id_eq%5D=#{resource.id}&order=id_desc/' target='_blank'>View resource translations in QUL</a>
                   \n <a href='https://quranenc.com/en/browse/#{version['key']}/' target='_blank'>View translation on QuranEnc</a>"

    todo.save(validate: false)

    ActiveAdmin::Comment.create(
      namespace: 'admin',
      resource: todo,
      author_type: 'User',
      author_id: 1,
      body: "<a href='https://quranenc.com/en/browse/#{version['key']}/' target='_blank'>View translation on QuranEnc</a>"
    )
  end

  def report_new_translation(version)
    key = version['key']

    if translation = importer.get_translation_for_key(key)
      language = Language.find_by(iso_code: translation['language_iso_code'])

      resource = ResourceContent.where("meta_data ->> 'quranenc-key' = '#{key}'").first_or_initialize
      title = resource.name.presence || translation['title'] || key.humanize

      resource.name = title
      resource.language ||= language
      resource.cardinality_type = ResourceContent::CardinalityType::OneVerse
      resource.resource_type_name = ResourceContent::ResourceType::Content
      resource.sub_type = ResourceContent::SubType::Translation

      resource.set_meta_value("source", 'quranenc')
      resource.set_meta_value("quranenc-key", key)
      resource.set_meta_value("version-on-quran-enc", version['version'])
      resource.set_meta_value("updated-timestamp-on-quran_enc", version['last_update'])
      resource.set_meta_value("updated-date-on-quran-enc", Time.at(version['last_update']).strftime('%B %d, %Y at %I:%M %P %Z'))

      resource.save(validate: false)
    end

    todo = AdminTodo.where(
      resource_content_id: resource.id,
      is_finished: false,
      tags: 'new-translation'
    ).first_or_initialize

    todo.description = "New translation is available on QuranEcn.
                   \n Name: <strong>#{resource.name}</strong>(##{resource.id}).
                   \n Key: #{version['key']}
                   \n <a href='https://qul.tarteel.ai/admin/resource_contents/#{resource.id}' target='_blank'>View resource in QUL</a>
                   \n <a href='https://qul.tarteel.ai/admin/translations?q%5Bresource_content_id_eq%5D=#{resource.id}&order=id_desc/' target='_blank'>View resource translations in QUL</a>
                   \n <a href='https://quranenc.com/en/browse/#{version['key']}/' target='_blank'>View translation on QuranEnc</a>"

    todo.save

    ActiveAdmin::Comment.create(
      namespace: 'admin',
      resource: todo,
      author_type: 'User',
      author_id: 1,
      body: "<a href='https://quranenc.com/en/browse/#{key}/' target='_blank'>View translation on QuranEnc</a>"
    )
  end

  def fetch_translation_versions
    importer.get_change_log
  end

  def fetch_translations
    importer.get_translations
  end

  def lookup_resource_content(quranenc_key)
    if resource = ResourceContent.where("meta_data ->> 'quranenc-key' = '#{quranenc_key}'").first
      resource.records_count.to_i > 1 ? resource : nil
    end
  end
end
