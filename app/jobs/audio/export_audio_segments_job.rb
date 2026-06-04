module Audio
  class ExportAudioSegmentsJob < ApplicationJob
    queue_as :default
    def perform(file_name: 'segments', table_name: 'ayah_timing', user_id:, recitations_ids: [], gapless: false, format: 'sqlite', manifest_version: 1)
      exporter = AudioSegment::Tarteel.new(
        file_name: file_name,
        table_name: table_name,
        recitations_ids: recitations_ids,
        gapless: gapless,
        manifest_version: manifest_version
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

      DeveloperMailer.notify(
        to: admin.email,
        subject: "Audio segments dump file (format: #{format})",
        message: email_body(admin, issues, format),
        file_path: file_path
      ).deliver_now
    end

    def email_body(user, issues, format)
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
#{issues_html(issues)}

Best regards,
      EMAIL
    end

    def issues_html(issues)
      return '' if issues.blank?

      rows = issues.map { |issue| issue_row(issue) }.join

      <<-HTML
<div style="margin-top:24px;">
  <h2 style="color:#b91c1c;font-size:18px;margin:0 0 12px;">Found #{issues.length} issue#{'s' unless issues.length == 1} with export</h2>
  <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;max-width:640px;border-collapse:collapse;border:1px solid #e5e7eb;border-radius:6px;overflow:hidden;font-size:14px;">
    #{rows}
  </table>
</div>
      HTML
    end

    def issue_row(issue)
      link = issue_link(issue)
      action = if link
                 "<a href=\"#{link}\" style=\"display:inline-block;padding:6px 14px;background:#2563eb;color:#ffffff;text-decoration:none;border-radius:4px;font-size:13px;white-space:nowrap;\">View</a>"
               else
                 ''
               end

      <<-ROW
<tr>
  <td style="padding:12px 14px;border-bottom:1px solid #e5e7eb;color:#374151;line-height:1.4;">#{issue}</td>
  <td style="padding:12px 14px;border-bottom:1px solid #e5e7eb;text-align:right;vertical-align:top;">#{action}</td>
</tr>
      ROW
    end

    def issue_link(issue)
      match = issue.match(/Recitation:\s*(\d+)\s+ayah\s+(\d+):(\d+)/)
      return unless match

      reciter_id, chapter_id, verse = match.captures
      "https://qul.tarteel.ai/surah_audio_files/#{reciter_id}/segment_builder?chapter_id=#{chapter_id}&verse=#{verse}"
    end
  end
end
