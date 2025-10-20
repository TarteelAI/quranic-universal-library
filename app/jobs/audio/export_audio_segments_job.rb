module Audio
  class ExportAudioSegmentsJob < ApplicationJob
    queue_as :default
    def perform(file_name:, table_name: 'ayah_timing', user_id:, recitations_ids: [], gapless: false, format: 'sqlite')
      exporter = AudioSegment::Tarteel.new(
        file_name: file_name,
        table_name: table_name,
        recitations_ids: recitations_ids,
        gapless: gapless
      )

      if format.to_s == 'json'
        file_path = exporter.export_json_files
      else
        file_path = exporter.export
      end

      send_email(file_path, user_id, exporter.issues, format)
    end

    protected

    def send_email(file_path, user_id, issues, format)
      admin = User.find(user_id)

      `bzip2 #{file_path}`

      zip_path = "#{file_path}.bz2"

      DeveloperMailer.notify(
        to: admin.email,
        subject: "Audio segments dump file (format: #{format})",
        message: email_body(admin, issues, format),
        file_path: zip_path
      ).deliver_now
    end

    def email_body(user, issues, format)
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

      format_note = if format.to_s == 'json'
                      "<p>You requested JSON per-surah gapless exports. Each reciter/surah file inside the attached archive is named:\n<code>reciter/&lt;reciter_id&gt;/&lt;surah_num&gt;.json.zip</code></p>"
                    else
                      "<p>You requested SQLite export. The attached file contains the SQLite exported table.</p>"
                    end

      <<-EMAIL
<p>Assalamu Alaikum #{user.name},</p>
<p>
Attached are the exported audio timing db for your selected recitations. Please find the details in the attached SQLite database.
</p>
#{format_note}
<p>
If you have any questions or need further assistance, feel free to reach out.
</p>
#{issues_list.join('') if issues_list.present?}

Best regards,
      EMAIL
    end
  end
end
