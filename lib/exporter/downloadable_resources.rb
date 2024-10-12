# Usage
# s = Exporter::DownloadableResources.new
# s.export_all # This will export all the resources
# s.export_surah_info # export surah info
# s.export_mutashabihat (resource_content: ResourceContent.find(941))

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
      export_mushaf_layouts
      export_similar_ayah
      export_mutashabihat
      export_quranic_morphology_data
    end

    def export_mushaf_layouts(resource_content: nil)
      # TODO: add tags
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
        tags = [] #['indopak', '13 lines', 'uthmani', 'Glyph font']
        downloadable_resource.tags = tags.compact_blank.join(', ')
        downloadable_resource.save(validate: false)

        if !content.name.include?('image')
          docx = exporter.export_docs
          create_download_file(downloadable_resource, docx, 'docx')
        end

        sqlite = exporter.export_sqlite

        # create_download_file(downloadable_resource, json, 'json')
        create_download_file(downloadable_resource, sqlite, 'sqlite')
      end
    end

    def export_quran_topics
      # TODO: add tags
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
      downloadable_resource.tags = resource.language_name.humanize
      downloadable_resource.save(validate: false)

      sqlite = exporter.export_sqlite
      create_download_file(downloadable_resource, sqlite, 'sqlite')
    end

    def export_quranic_morphology_data(resource_content: nil)
      base_path = "tmp/export/morphology"
      FileUtils.mkdir_p(base_path)

      list = ResourceContent.morphology.approved

      if resource_content
        list = list.where(id: resource_content.id)
      end

      list.each do |resource|
        exporter = Exporter::ExportQuranicMorphology.new(
          resource_content: resource,
          base_path: base_path
        )

        downloadable_resource = DownloadableResource.where(
          resource_content: resource,
          resource_type: 'morphology',
          cardinality_type: ResourceContent::CardinalityType::OneWord
        ).first_or_initialize

        downloadable_resource.name ||= resource.name
        downloadable_resource.tags = ['Quranic Morphology', resource.name.split(/\s+/).last].compact_blank.join(',')
        downloadable_resource.save(validate: false)

        sqlite = exporter.export_sqlite
        create_download_file(downloadable_resource, sqlite, 'sqlite')
      end
    end

    def export_ayah_themes
      # TODO: add tags
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
      tags = [resource.language_name.humanize, 'Ayah Theme']
      downloadable_resource.tags = tags.compact_blank.join(',')
      downloadable_resource.save(validate: false)

      sqlite = exporter.export_sqlite
      create_download_file(downloadable_resource, sqlite, 'sqlite')
    end

    def export_mutashabihat
      base_path = "tmp/export/mutashabihat"
      FileUtils.mkdir_p(base_path)

      resource = ResourceContent
                   .where(
                     sub_type: ResourceContent::SubType::Mutashabihat
                   )
                   .first

      exporter = Exporter::ExportMutashabihat.new(
        base_path: base_path,
        min_phrase_length: 3
      )

      json = exporter.export_json
      #sqlite = exporter.export_sqlite

      downloadable_resource = DownloadableResource.where(
        resource_content: resource,
        resource_type: 'mutashabihat',
        cardinality_type: ResourceContent::CardinalityType::OnePhrase
      ).first_or_initialize

      downloadable_resource.name ||= resource.name
      downloadable_resource.language = resource.language
      downloadable_resource.tags = 'Mutashabihat'
      downloadable_resource.save(validate: false)

      create_download_file(downloadable_resource, json, 'json')
      #create_download_file(downloadable_resource, sqlite, 'sqlite')
    end

    def export_similar_ayah
      base_path = "tmp/export/matching_ayah"
      FileUtils.mkdir_p(base_path)

      resource = ResourceContent.where(name: 'Similar Ayah').first_or_create

      exporter = Exporter::ExportMatchingAyah.new(
        base_path: base_path,
        min_match_score: 50
      )

      json = exporter.export_json
      sqlite = exporter.export_sqlite

      downloadable_resource = DownloadableResource.where(
        resource_content: resource,
        resource_type: 'similar-ayah',
        cardinality_type: ResourceContent::CardinalityType::OneVerse
      ).first_or_initialize

      downloadable_resource.name ||= resource.name
      downloadable_resource.language = resource.language
      downloadable_resource.tags = 'Similar Ayah'
      downloadable_resource.save(validate: false)

      create_download_file(downloadable_resource, json, 'json')
      create_download_file(downloadable_resource, sqlite, 'sqlite')
    end

    def export_tafsirs(resource_content: nil)
      # TODO: add tags
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
        tags = [content.language_name.humanize]

        if content.has_footnote?
          tags << 'With Footnotes'
        end

        downloadable_resource.tags = tags.join(', ')
        downloadable_resource.save(validate: false)

        json = exporter.export_json(with_footnotes: false)
        sqlite = exporter.export_sqlite(with_footnotes: false)

        create_download_file(downloadable_resource, json, 'simple.json')
        create_download_file(downloadable_resource, sqlite, 'simple.sqlite')

        if content.has_footnote?
          json_with_footnotes = exporter.export_json_with_footnotes_tags
          json_with_inline_footnotes = exporter.export_json_with_inline_footnotes
          json_with_footnotes_chunks = exporter.export_json_with_footnotes_chunks

          sqlite_with_footnotes = exporter.export_sqlite_with_footnotes_tags
          sqlite_with_inline_footnotes = exporter.export_sqlite_with_inline_footnotes
          sqlite_with_footnotes_chunks = exporter.export_sqlite_with_footnotes_chunks

          create_download_file(downloadable_resource, json_with_footnotes, 'translation-with-footnote-tags.json')
          create_download_file(downloadable_resource, json_with_inline_footnotes, 'translation-with-inline-footnote.json')
          create_download_file(downloadable_resource, json_with_footnotes_chunks, 'translation-text-chunk.json')

          create_download_file(downloadable_resource, sqlite_with_footnotes, 'translation-with-footnote-tags.sqlite')
          create_download_file(downloadable_resource, sqlite_with_inline_footnotes, 'translation-with-inline-footnote.sqlite')
          create_download_file(downloadable_resource, sqlite_with_footnotes_chunks, 'translation-text-chunk.sqlite')
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
        tags = [content.language_name.humanize, 'Transliteration']
        downloadable_resource.tags = tags.join(', ')
        downloadable_resource.save(validate: false)

        json = exporter.export_json(with_footnotes: false)
        create_download_file(downloadable_resource, json, 'json')

        sqlite = exporter.export_sqlite(name: 'transliteration', with_footnotes: false)
        create_download_file(downloadable_resource, sqlite, 'sqlite')
      end
    end

    def export_word_translations(resource_content: nil)
      base_path = "tmp/export/word_translations"
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
        tags = [content.language_name.humanize, 'Translation']
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
        tags = [content.language_name.humanize, 'Transliteration']
        downloadable_resource.tags = tags.join(', ')
        downloadable_resource.save(validate: false)

        json = exporter.export_json
        sqlite = exporter.export_sqlite
        create_download_file(downloadable_resource, json, 'json')
        create_download_file(downloadable_resource, sqlite, 'sqlite')
      end
    end

    def export_quran_metadata(resource_content: nil)
      base_path = "tmp/export/quran-metadata"
      FileUtils.mkdir_p(base_path)

      list = ResourceContent.quran_metadata

      if resource_content
        list = list.where(id: resource_content.id)
      end

      list.each do |resource|
        exporter = Exporter::ExportQuranMetaData.new(
          resource_content: resource,
          base_path: base_path
        )

        downloadable_resource = DownloadableResource.where(
          resource_content: resource,
          resource_type: 'quran-metadata',
          cardinality_type: resource.cardinality_type
        ).first_or_initialize

        downloadable_resource.name ||= resource.name
        tags = ['Quran', 'Metadata', resource.name]

        downloadable_resource.tags = tags.compact_blank.join(', ')
        downloadable_resource.save(validate: false)

        json = exporter.export_json
        sqlite = exporter.export_sqlite
        create_download_file(downloadable_resource, json, 'json')
        create_download_file(downloadable_resource, sqlite, 'sqlite')
      end
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
        next if recitation.blank?
        recitation.name ||= content.name

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
        tags = ['Recitation', recitation.recitation_style&.name, recitation.qirat_type&.name]

        if content.has_segments?
          tags << 'With segments'
        end

        if recitation.chapter_audio_files.size < 114
          tags << 'Partial'
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
          base_path: base_path,
          resource_content: content
        )

        downloadable_resource = DownloadableResource.where(
          resource_content: content,
          resource_type: 'recitation',
          cardinality_type: ResourceContent::CardinalityType::OneVerse
        ).first_or_initialize

        downloadable_resource.name ||= content.name
        tags = ['Recitation', recitation.recitation_style&.name, recitation.qirat_type&.name]

        if content.has_segments?
          tags << 'With segments'
        end

        if recitation.audio_files.size < Verse.count
          tags << 'Partial'
        end

        downloadable_resource.tags = tags.compact_blank.join(', ')
        downloadable_resource.save(validate: false)

        json = exporter.export_json
        sqlite = exporter.export_sqlite
        create_download_file(downloadable_resource, json, 'json')
        create_download_file(downloadable_resource, sqlite, 'sqlite')
      end
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
      tags = ['Recitation', 'Waseem Sharif']
      downloadable_resource.tags = tags.compact_blank.join(', ')
      downloadable_resource.save(validate: false)

      json = exporter.export_json
      sqlite = exporter.export_sqlite
      create_download_file(downloadable_resource, json, 'json')
      create_download_file(downloadable_resource, sqlite, 'sqlite')
    end

    def export_ayah_quran_script(resource_content: nil)
      base_path = "tmp/export/ayah_script"
      FileUtils.mkdir_p(base_path)

      list = ResourceContent.quran_script.one_verse.approved

      if resource_content.present?
        list = list.where(id: resource_content.id)
      end

      list.each do |content|
        next if !content.allow_publish_sharing?

        exporter = Exporter::ExportQuranAyahScript.new(
          resource_content: content,
          base_path: base_path
        )

        downloadable_resource = DownloadableResource.where(
          resource_content: content,
          resource_type: 'quran-script',
          cardinality_type: ResourceContent::CardinalityType::OneVerse
        ).first_or_initialize

        downloadable_resource.name ||= content.name
        tags = ['Quran text', 'Hafs']

        if content.meta_value('font').present?
          fonts = content.meta_value('font').split('or').map(&:strip)
          tags += fonts
        end

        downloadable_resource.tags = tags.compact_blank.join(', ')
        downloadable_resource.save(validate: false)

        json = exporter.export_json
        sqlite = exporter.export_sqlite
        create_download_file(downloadable_resource, json, 'json')
        create_download_file(downloadable_resource, sqlite, 'sqlite')
      end
    end

    def export_wbw_quran_script(resource_content: nil)
      base_path = "tmp/export/wbw_script"
      FileUtils.mkdir_p(base_path)

      list = ResourceContent.quran_script.one_word.approved

      if resource_content.present?
        list = list.where(id: resource_content.id)
      end

      list.each do |content|
        next if !content.allow_publish_sharing?

        exporter = Exporter::ExportQuranWordScript.new(
          resource_content: content,
          base_path: base_path
        )

        downloadable_resource = DownloadableResource.where(
          resource_content: content,
          resource_type: 'quran-script',
          cardinality_type: ResourceContent::CardinalityType::OneWord
        ).first_or_initialize

        downloadable_resource.name ||= content.name
        tags = ['Quran text', 'Hafs']

        if content.has_mushaf_layout?
          tags << 'Mushaf layout'
        end

        if content.meta_value('font').present?
          fonts = content.meta_value('font').split('or').map(&:strip)
          tags += fonts
        end

        downloadable_resource.tags = tags.compact_blank.join(', ')
        downloadable_resource.save(validate: false)

        json = exporter.export_json
        sqlite = exporter.export_sqlite
        create_download_file(downloadable_resource, json, 'json')
        create_download_file(downloadable_resource, sqlite, 'sqlite')
      end
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
        downloadable_resource_id: resource.id,
        file_type: file_type,
      ).first_or_initialize

      zipped = zip(file_path)
      file.name ||= "#{resource.name}.#{file_type}"
      file.file.attach(
        io: File.open(zipped),
        filename: "#{file.name}.bz2",
        key: QulExportedFileKeyGenerator.generate_key(zipped, resource)
      )

      file.save(validate: false)
      resource.run_export_action
    end

    def zip(file_path)
      if File.directory?(file_path)
        zip_folder_path = "#{file_path}.zip"
        Zip::File.open(zip_folder_path, Zip::File::CREATE) do |zipfile|
          Dir[File.join(file_path, '**', '**')].each do |file|
            relative_path = file.sub("#{file_path}/", '')

            zipfile.add(relative_path, file) unless File.directory?(file)
          end
        end

        zip_folder_path
      else
        `bzip2 #{file_path}`

        "#{file_path}.bz2"
      end
    end
  end
end