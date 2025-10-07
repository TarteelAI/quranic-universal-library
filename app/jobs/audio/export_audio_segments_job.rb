module Audio
  class ExportAudioSegmentsJob < ApplicationJob
    def perform(file_name:, table_name: 'ayah_timing', user_id:, recitations_ids: [], gapless: false)
      exporter = AudioSegment::Tarteel.new(
        file_name: file_name,
        table_name: table_name,
        recitations_ids: recitations_ids,
        gapless: gapless
      )

      file_path = exporter.export
      send_email(file_path, user_id, exporter.issues)
    end

    protected

    def send_email(file_path, user_id, issues)
      admin = User.find(user_id)

      # zip the file
      `bzip2 #{file_path}`

      zip_path = "#{file_path}.bz2"

      DeveloperMailer.notify(
        to: admin.email,
        subject: "Audio segments dump file",
        message: email_body(admin, issues),
        file_path: zip_path
      ).deliver_now
    end

    def email_body(user, issues)
      issues_list = []

      if issues.present?
        issues_list = [
          "<h2>Found #{issues.length} issues with export</h2><ul>"
        ]
        issues.each do |issue|
          issues_list << "<li>#{issue}</li>"
        end
        issues_list << "</ul>"
      end

      <<-EMAIL
<p>Assalamu Alaikum #{user.name},</p>
<p>
Attached are the exported audio timing db for your selected recitations. Please find the details in the attached SQLite database.
</p>
<p>
If you have any questions or need further assistance, feel free to reach out.
<p>
#{issues_list.join('') if issues_list.present?}

Best regards,
      EMAIL
    end
  end
end