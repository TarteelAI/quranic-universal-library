module Export
  class RawTafsirJob < ApplicationJob
    attr_reader :file_name,
                :resource_content
    STORAGE_PATH = "#{Rails.root}/public/exported_databases"

    def perform(resource_id, original_file_name, user_id)
      user = User.find(user_id)
      @resource_content = ResourceContent.find(resource_id)

      setup(original_file_name)
      export_data
      compress
      send_email("#{file_name}.zip", user) if user.present?

      # return the db file path
      "#{file_name}.zip"
    end

    protected

    def setup(original_file_name)
      require 'fileutils'

      name = (original_file_name.presence || @resource_content.sqlite_file_name).chomp('.db')
      timestamp = Time.now
      file_path = "#{STORAGE_PATH}/#{timestamp.to_i}"
      FileUtils::mkdir_p file_path

      @file_name = "#{file_path}/#{name}-#{timestamp.strftime('%m-%d-%Y')}"
    end

    def export_data
      Chapter.find_each do |chapter|
        chapter_path = "#{file_name}/#{chapter.id}"
        FileUtils.mkdir_p(chapter_path)

        chapter.verses.each do |verse|
          tafsir = Tafsir.where(
            archived: false,
            resource_content_id: resource_content.id,
            verse_id: verse.id
          ).first

          if tafsir
            File.open("#{chapter_path}/#{verse.verse_number}.html", "wb") do |file|
              file.puts tafsir.text
            end
          end
        end
      end
    end

    def compress
      require 'zip'

      Zip::File.open("#{file_name}.zip", Zip::File::CREATE) do |zipfile|
        Dir["#{file_name}/**/*"].each do |file|
          relative_path = file.sub("#{file_name}/", '')
          zipfile.add(relative_path, file)
        end
      end
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