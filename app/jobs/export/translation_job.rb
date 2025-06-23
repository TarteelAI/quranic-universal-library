=begin
ExportService::TRANSLATION_NAME_MAPPIMG.keys.each do |id|
  Export::TranslationJob.perform_now(id, 1)
end
=end

module Export
  class TranslationJob < ApplicationJob
    attr_reader :file_name,
                :resource_content
    STORAGE_PATH = "#{Rails.root}/public/exported_translations"

    def perform(resource_id, user_id, use_nested_array_format = false)
      @resource_content = ResourceContent.find(resource_id)
      @resource_content.touch

      setup

      if use_nested_array_format
        export_nested_array
      else
        export_data
      end

      compress if Rails.env.production?

      if user_id.present? && Rails.env.production?
        user = User.find(user_id)
        send_email("#{file_name}.bz2", user)
      end

      # return the db file path
      Rails.env.production? ? "#{file_name}.bz2" : file_name
    end

    protected

    def setup(versioned: true)
      require 'fileutils'

      name = ExportService.new(resource_content).get_export_file_name
      file_path = STORAGE_PATH

      FileUtils::mkdir_p file_path

      if versioned
        @file_name = "#{file_path}/#{name}-#{resource_content.updated_at.to_i}.json"
      else
        @file_name = "#{file_path}/#{name}.json"
      end
    end

    def export_nested_array
      data = []

      Chapter.order('chapter_number ASC').each do |chapter|
        data[chapter.id - 1] = []
        chapter.verses.order('verse_number ASC').each do |verse|
          translation = Translation.where(
            resource_content_id: resource_content.id,
            verse_id: verse.id
          ).first

          doc = Nokogiri::HTML::DocumentFragment.parse(translation&.text.to_s)
          doc.css('sup, a.sup').each do |node|
            node.remove
          end

          if resource_content.id == 149
            # Bridges qiraat footnote
            doc.css('span, i').each do |a_tag|
              content = a_tag.content
              a_tag.replace(content)
            end
          end

          data[chapter.id - 1] << doc.to_s.strip
        end
      end

      File.open(file_name, 'wb') do |file|
        file << JSON.generate(data, { state: JsonNoEscapeHtmlState.new })
      end
    end

    def export_data
      json = {}
      s = Exporter::AyahTranslation.new

      Chapter.order('chapter_number ASC').each do |chapter|
        chapter.verses.order('verse_number ASC').each do |verse|
          translation = Translation.where(
            resource_content_id: resource_content.id,
            verse_id: verse.id
          ).first

          data = s.export_chunks(translation)
          data.delete(:f) if data[:f].blank?

          json[verse.verse_key] = data
        end
      end

      File.open(file_name, 'wb') do |file|
        file << JSON.generate(json, { state: JsonNoEscapeHtmlState.new })
      end
    end

    def compress
      `bzip2 #{file_name}`
    end

    def send_email(zip_path, user)
      DeveloperMailer.notify(
        to: user.email,
        subject: "#{@resource_content.name} files export",
        message: "Please see the attached zip",
        file_path: zip_path
      ).deliver_now
    end
  end
end