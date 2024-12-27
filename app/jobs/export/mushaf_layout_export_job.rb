module Export
  class MushafLayoutExportJob < ApplicationJob
    STORAGE_PATH = "#{Rails.root}/tmp/exported_mushaf_layouts"

    def perform(file_name:,  user_id:, mushaf_ids: [])
      require 'sqlite3'
      @mushaf_ids = mushaf_ids

      file_path = prepare_file_paths(file_name)
      export_sqlite_db(file_path, mushaf_ids)
      send_email(file_path, user_id)
    end

    protected

    def prepare_file_paths(file_name)
      file_path = "#{STORAGE_PATH}/#{Time.now.to_i}"
      FileUtils::mkdir_p file_path

      "#{file_path}/#{file_name}"
    end

    def export_sqlite_db(file_name, mushaf_ids)
      mushafs = load_mushafs(mushaf_ids)
      export_service = ExportMushafLayout.new
      export_service.export(mushafs.pluck(:id), file_name)

      @export_stats = export_service.export_stats
    end

    def send_email(file_path, user_id)
      admin = User.find(user_id)

      # zip the file
      `bzip2 #{file_path}`

      zip_path = "#{file_path}.bz2"

      DeveloperMailer.notify(
        to: admin.email,
        subject: "Mushaf layouts data file",
        message: email_body(admin),
        file_path: zip_path
      ).deliver_now
    end

    def email_body(user)
      email_body = <<-EMAIL
Assalamu Alaikum #{user.name},<br><br>

Mushaf layouts data is exported and attached with this email.<br><br>

      #{
        if user.id == 1
          "<h3>Validation:</h3>" +
            "<ul>" +
            @export_stats.map { |key, value| "<li><strong>#{key.to_s.humanize}:</strong> #{value}</li>" }.join +
            "</ul><br>"
        end
      }

If you have any questions or need further assistance, feel free to reach out.<br><br>

Best regards,<br>
EMAIL

    end

    def load_mushafs(mushaf_ids)
      if mushaf_ids == ['tarteel-mushafs']
        tag = Tag.where(name: 'Tarteel mushafs').first
        resources = ResourceContent
                      .joins(:resource_tags)
                      .where(resource_tags: { tag_id: tag.id })
        Mushaf.where(resource_content_id: resources.pluck(:id))
      else
        Mushaf.where(id: mushaf_ids.map(&:to_i))
      end
    end
  end
end