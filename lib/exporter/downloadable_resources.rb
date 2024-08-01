# Usage
# s = Exporter::DownloadableResources.new
# s.export_all # This will export all the resources
# s.export_surah_info # export surah info
# s.export_ayah_recitation(resource_content: ResourceContent.find(941))

require 'zip'

module Exporter
  class DownloadableResources
    def export_all
      FileUtils.rmdir("tmp/export")

      export_surah_info
      export_tafsirs
      export_ayah_translations
      export_ayah_transliteration
      export_word_transliteration
      export_word_translations
      export_quran_topics
      export_ayah_themes
      export_surah_recitation
      export_ayah_recitation
      export_wbw_recitation

      export_wbw_quran_script
      export_ayah_quran_script
      export_quran_metadata
      export_similar_ayah
      export_mutashabihat
      export_grammar_data
      export_mushaf_layouts
    end

    def export_mushaf_layouts(resource_content: nil)
      base_path = "tmp/export/mushaf_layouts"
      FileUtils.mkdir_p(base_path)

      list = ResourceContent.mushaf_layout.approved

      if resource_content.present?
        list = list.where(id: resource_content.id)
      end

      list.each do |content|
        exporter = Exporter::ExportMushafLayout.new(
          resource_content: content,
          base_path: base_path
        )

        downloadable_resource = DownloadableResource.where(
          resource_content: content,
          resource_type: 'mushaf-layout',
          cardinality_type: ResourceContent::CardinalityType::OnePage
        ).first_or_initialize

        downloadable_resource.name ||= content.name
        downloadable_resource.published = true
        tags = [] #['indopak', '13 lines', 'uthmani', 'Glyph font']
        downloadable_resource.tags = tags.compact_blank.join(', ')
        downloadable_resource.save(validate: false)

        #  json = exporter.export_json
        sqlite = exporter.export_sqlite

        # create_download_file(downloadable_resource, json, 'json')
        create_download_file(downloadable_resource, sqlite, 'sqlite')
      end
    end

    def export_quran_topics
      base_path = "tmp/export/quran_topics"
      FileUtils.mkdir_p(base_path)

      resource = ResourceContent.quran_topics.first

      exporter = Exporter::ExportTopics.new(
        resource_content: resource,
        base_path: base_path
      )

      downloadable_resource = DownloadableResource.where(
        resource_content: resource,
        resource_type: 'ayah-topics',
        cardinality_type: ResourceContent::CardinalityType::OneVerse
      ).first_or_initialize

      downloadable_resource.name ||= resource.name
      downloadable_resource.language = resource.language
      downloadable_resource.published = true
      downloadable_resource.tags = resource.language_name.humanize
      downloadable_resource.save(validate: false)

      sqlite = exporter.export_sqlite
      create_download_file(downloadable_resource, sqlite, 'sqlite')
    end

    def export_grammar_data

    end

    def export_ayah_themes
      base_path = "tmp/export/ayah_themse"
      FileUtils.mkdir_p(base_path)

      resource = ResourceContent.where(name: 'Ayah theme').first

      exporter = Exporter::ExportAyahTheme.new(
        resource_content: resource,
        base_path: base_path
      )

      downloadable_resource = DownloadableResource.where(
        resource_content: resource,
        resource_type: 'ayah-theme',
        cardinality_type: ResourceContent::CardinalityType::OneVerse
      ).first_or_initialize

      downloadable_resource.name ||= resource.name
      downloadable_resource.language = resource.language
      downloadable_resource.published = true
      downloadable_resource.tags = resource.language_name.humanize
      downloadable_resource.save(validate: false)

      sqlite = exporter.export_sqlite
      create_download_file(downloadable_resource, sqlite, 'sqlite')
    end

    def export_mutashabihat

    end

    def export_similar_ayah

    end

    def export_tafsirs(resource_content: nil)
      base_path = "tmp/export/tafsirs"
      FileUtils.mkdir_p(base_path)

      list = ResourceContent.tafsirs.approved

      if resource_content.present?
        list = list.where(id: resource_content.id)
      end

      list.each do |content|
        exporter = Exporter::ExportTafsir.new(
          resource_content: content,
          base_path: base_path
        )

        json = exporter.export_json
        sqlite = exporter.export_sqlite

        downloadable_resource = DownloadableResource.where(
          resource_content: content,
          resource_type: 'tafsir',
          cardinality_type: ResourceContent::CardinalityType::NVerse
        ).first_or_initialize

        downloadable_resource.name ||= content.name
        downloadable_resource.language = content.language
        # downloadable_resource.info ||= resource_content.info
        downloadable_resource.published = true
        downloadable_resource.tags = content.language_name.humanize
        downloadable_resource.save(validate: false)

        create_download_file(downloadable_resource, json, 'json')
        create_download_file(downloadable_resource, sqlite, 'sqlite')
      end
    end

    def export_ayah_translations(resource_content: nil)
      base_path = "tmp/export/translations"
      FileUtils.mkdir_p(base_path)

      list = ResourceContent.translations.one_verse.approved

      if resource_content.present?
        list = list.where(id: resource_content.id)
      end

      list.each do |content|
        next if !content.allow_publish_sharing?

        exporter = Exporter::ExportTranslation.new(
          resource_content: content,
          base_path: base_path
        )

        downloadable_resource = DownloadableResource.where(
          resource_content: content,
          resource_type: 'translation',
          cardinality_type: ResourceContent::CardinalityType::OneVerse
        ).first_or_initialize

        downloadable_resource.name ||= content.name
        downloadable_resource.language_id = content.language_id
        # downloadable_resource.info ||= resource_content.info
        downloadable_resource.published = true
        tags = [content.language_name.humanize]

        if content.has_footnote?
          tags << 'With Footnotes'
        end

        downloadable_resource.tags = tags.join(', ')
        downloadable_resource.save(validate: false)

        json = exporter.export_json
        create_download_file(downloadable_resource, json, 'json')

        if content.has_footnote?
          json_with_footnotes = exporter.export_json_with_footnotes_tags
          create_download_file(downloadable_resource, json_with_footnotes, 'footnote.json')
        end
      end
    end

    def export_ayah_transliteration
      base_path = "tmp/export/transliterations"
      FileUtils.mkdir_p(base_path)

      list = ResourceContent.transliteration.one_verse.approved

      list.each do |content|
        exporter = Exporter::ExportTranslation.new(
          resource_content: content,
          base_path: base_path
        )

        downloadable_resource = DownloadableResource.where(
          resource_content: content,
          resource_type: 'transliteration',
          cardinality_type: ResourceContent::CardinalityType::OneVerse
        ).first_or_initialize

        downloadable_resource.name ||= content.name
        downloadable_resource.language_id = content.language_id
        downloadable_resource.published = true
        tags = [content.language_name.humanize]
        downloadable_resource.tags = tags.join(', ')
        downloadable_resource.save(validate: false)

        json = exporter.export_json(ignore_footnotes: true)
        create_download_file(downloadable_resource, json, 'json')
      end
    end

    def export_word_translations(resource_content: nil)
      base_path = "tmp/export/word_transliterations"
      FileUtils.mkdir_p(base_path)

      list = ResourceContent.translations.one_word.approved.where('records_count > 0')

      if resource_content.present?
        list = list.where(id: resource_content.id)
      end

      list.each do |content|
        next if !content.allow_publish_sharing?

        exporter = Exporter::ExportWordTranslation.new(
          resource_content: content,
          base_path: base_path
        )

        downloadable_resource = DownloadableResource.where(
          resource_content: content,
          resource_type: 'translation',
          cardinality_type: ResourceContent::CardinalityType::OneWord
        ).first_or_initialize

        downloadable_resource.name ||= content.name
        downloadable_resource.language_id = content.language_id
        downloadable_resource.published = true
        tags = [content.language_name.humanize]
        downloadable_resource.tags = tags.join(', ')
        downloadable_resource.save(validate: false)

        json = exporter.export_json
        sqlite = exporter.export_sqlite
        create_download_file(downloadable_resource, json, 'json')
        create_download_file(downloadable_resource, sqlite, 'sqlite')
      end
    end

    def export_word_transliteration
      base_path = "tmp/export/word_transliterations"
      FileUtils.mkdir_p(base_path)

      list = ResourceContent.transliteration.one_word.approved

      list.each do |content|
        exporter = Exporter::ExportWordTransliteration.new(
          resource_content: content,
          base_path: base_path
        )

        downloadable_resource = DownloadableResource.where(
          resource_content: content,
          resource_type: 'transliteration',
          cardinality_type: ResourceContent::CardinalityType::OneWord
        ).first_or_initialize

        downloadable_resource.name ||= content.name
        downloadable_resource.language_id = content.language_id
        downloadable_resource.published = true
        tags = [content.language_name.humanize]
        downloadable_resource.tags = tags.join(', ')
        downloadable_resource.save(validate: false)

        json = exporter.export_json
        sqlite = exporter.export_sqlite
        create_download_file(downloadable_resource, json, 'json')
        create_download_file(downloadable_resource, sqlite, 'sqlite')
      end
    end

    def export_quran_metadata

    end

    def export_surah_recitation(resource_content: nil)
      base_path = "tmp/export/surah_recitation"
      FileUtils.mkdir_p(base_path)

      list = ResourceContent.recitations.one_chapter.approved

      if resource_content.present?
        list = list.where(id: resource_content.id)
      end

      list.each do |content|
        next if !content.allow_publish_sharing?
        recitation = Audio::Recitation.where(resource_content_id: content.id).first

        exporter = Exporter::ExportSurahRecitation.new(
          recitation: recitation,
          base_path: base_path
        )

        downloadable_resource = DownloadableResource.where(
          resource_content: content,
          resource_type: 'recitation',
          cardinality_type: ResourceContent::CardinalityType::OneChapter
        ).first_or_initialize

        downloadable_resource.name ||= content.name
        downloadable_resource.published = true
        tags = [recitation.recitation_style&.name, recitation.qirat_type&.name]

        if content.has_segments?
          tags << 'With segments'
        end

        if recitation.chapter_audio_files.size < 114
          tags << 'Partial Recitation'
        end

        downloadable_resource.tags = tags.compact_blank.join(', ')
        downloadable_resource.save(validate: false)

        json = exporter.export_json
        sqlite = exporter.export_sqlite
        create_download_file(downloadable_resource, json, 'json')
        create_download_file(downloadable_resource, sqlite, 'sqlite')
      end
    end

    def export_ayah_recitation(resource_content: nil)
      base_path = "tmp/export/ayah_recitation"
      FileUtils.mkdir_p(base_path)

      list = ResourceContent.recitations.one_verse.approved

      if resource_content.present?
        list = list.where(id: resource_content.id)
      end

      list.each do |content|
        next if !content.allow_publish_sharing?
        recitation = Recitation.where(resource_content_id: content.id).first

        exporter = Exporter::ExportAyahRecitation.new(
          recitation: recitation,
          base_path: base_path
        )

        downloadable_resource = DownloadableResource.where(
          resource_content: content,
          resource_type: 'recitation',
          cardinality_type: ResourceContent::CardinalityType::OneVerse
        ).first_or_initialize

        downloadable_resource.name ||= content.name
        downloadable_resource.published = true
        tags = [recitation.recitation_style&.name, recitation.qirat_type&.name]

        if content.has_segments?
          tags << 'With segments'
        end

        if recitation.audio_files.size < Verse.count
          tags << 'Partial Recitation'
        end

        downloadable_resource.tags = tags.compact_blank.join(', ')
        downloadable_resource.save(validate: false)

        json = exporter.export_json
        sqlite = exporter.export_sqlite
        create_download_file(downloadable_resource, json, 'json')
        create_download_file(downloadable_resource, sqlite, 'sqlite')
      end
    end

    def export_wbw_quran_script
      base_path = "tmp/export/wbw_script"
      FileUtils.mkdir_p(base_path)
    end

    def export_wbw_recitation
      base_path = "tmp/export/word_recitation"
      FileUtils.mkdir_p(base_path)

      content = ResourceContent.recitations.one_word.approved.first
      exporter = Exporter::ExportWordRecitation.new(base_path: base_path)

      downloadable_resource = DownloadableResource.where(
        resource_content: content,
        resource_type: 'recitation',
        cardinality_type: ResourceContent::CardinalityType::OneWord
      ).first_or_initialize

      downloadable_resource.name ||= content.name
      downloadable_resource.published = true
      tags = ['Waseem Sharif']
      downloadable_resource.tags = tags.compact_blank.join(', ')
      downloadable_resource.save(validate: false)

      json = exporter.export_json
      sqlite = exporter.export_sqlite
      create_download_file(downloadable_resource, json, 'json')
      create_download_file(downloadable_resource, sqlite, 'sqlite')
    end

    def export_ayah_quran_script

    end

    def export_surah_info(language: nil)
      list = ResourceContent
               .chapter_info
               .approved

      base_path = "tmp/export/surah_info"
      FileUtils.mkdir_p(base_path)

      if language.present?
        list = list.where(language_id: language.id)
      end

      list.each do |resource_content|
        exporter = Exporter::ExportSurahInfo.new(
          language: resource_content.language,
          base_path: base_path
        )

        downloadable_resource = DownloadableResource.where(
          resource_content: resource_content,
          resource_type: 'surah-info',
          cardinality_type: ResourceContent::CardinalityType::OneChapter,
          language: resource_content.language
        ).first_or_initialize

        downloadable_resource.name = "Surah Info - #{resource_content.language_name.humanize}"
        downloadable_resource.info = "Surah information in #{resource_content.language.name} language"
        downloadable_resource.published = true
        downloadable_resource.tags = "Surah Info, #{resource_content.language.name}"
        downloadable_resource.save(validate: false)

        csv = exporter.export_csv
        json = exporter.export_json
        sqlite = exporter.export_sqlite

        create_download_file(downloadable_resource, csv, 'csv')
        create_download_file(downloadable_resource, json, 'json')
        create_download_file(downloadable_resource, sqlite, 'sqlite')
      end
    end

    protected

    def create_download_file(resource, file_path, file_type)
      file = DownloadableFile.where(
        downloadable_resource: resource,
        file_type: file_type,
      ).first_or_initialize

      if File.directory?(file_path)
        zip_folder_path = "#{file_path}.zip"
        Zip::File.open(zip_folder_path, Zip::File::CREATE) do |zipfile|
          Dir[File.join(file_path, '**', '**')].each do |file|
            relative_path = file.sub("#{file_path}/", '')

            zipfile.add(relative_path, file) unless File.directory?(file)
          end
        end

        zipped = zip_folder_path
      else
        `bzip2 #{file_path}`
        zipped = "#{file_path}.bz2"
      end

      file.name ||= "#{resource.name}.#{file_type}"
      file.file.attach(
        io: File.open(zipped),
        filename: "#{file.name}.bz2"
      )

      file.save(validate: false)
    end
  end
end