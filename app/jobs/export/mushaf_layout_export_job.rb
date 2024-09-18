module Export
  class MushafLayoutExportJob < ApplicationJob
    STORAGE_PATH = "#{Rails.root}/tmp/exported_mushaf_layouts"

    def perform(file_name:,  user_id:, mushaf_ids: [])
      require 'sqlite3'
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

      ExportMushafLayout.new.export(mushafs.pluck(:id), file_name)
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
      <<-EMAIL
Assalamu Alaikum #{user.name},

Mushaf layouts data is exported and attached with this email.

If you have any questions or need further assistance, feel free to reach out.

Best regards,
      EMAIL
    end

    def load_mushafs(mushaf_ids)
      if mushaf_ids == ['tarteel-mushafs']
        tag = Tag.where(name: 'Tarteel mushafs').first
        resources = ResourceContent
                      .joins(:resource_tags)
                      .where(resource_tags: { tag_id: tag.id })

        Mushaf.where(resource_content: resources)
      else
        Mushaf.where(id: mushaf_ids.map(&:to_i))
      end
    end
  end
end