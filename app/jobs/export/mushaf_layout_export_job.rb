module Export
  class MushafLayoutExportJob < ApplicationJob
    STORAGE_PATH = "#{Rails.root}/tmp/exported_mushaf_layouts"

    def perform(file_name:, user_id:, mushaf_ids: [])
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
      <<-EMAIL
<p>Assalamu Alaikum #{user.name},</p>
<p>
Mushaf layouts data is exported and attached with this email.</p>
      #{
        if user.id == 1
          render_layout_export_stats
        end
      }
<p>
Best regards,
</p>
      EMAIL
    end

    def render_layout_export_stats
      "<div style='font-family: Arial, sans-serif; padding: 10px; border: 1px solid #ddd; border-radius: 5px; background: #f9f9f9;'>
       <h3>Export stats</h3>
      #{render_stats(@export_stats)}
</div>".html_safe
    end

    def render_stats(hash, indent = 0)
      output = ""
      hash.each do |key, value|
        if value.is_a?(Hash)
          output += "<div style='margin-left: #{indent}px; padding: 5px; border-left: 2px solid #ddd;'>"
          output += "<strong style='color: #007BFF;'>#{key}:</strong>"
          output += render_stats(value, indent + 10)
          output += "</div>"
        elsif value.is_a?(Array)
          output += "<div style='margin-left: #{indent}px; padding: 5px; border-left: 2px solid #ddd;'>"
          output += "<strong style='color: #007BFF;'>#{key}:</strong>"
          output += "<ul style='margin: 0; padding-left: 15px;'>"
          value.each do |item|
            if item.is_a?(String) || item.is_a?(Numeric)
              output += "<li style='color: #28a745;'>#{item}</li>"
            else
              output += "<li>#{render_stats({ item: item }, indent + 10)}</li>"
            end
          end
          output += "</ul></div>"
        else
          color = (key.to_s == 'issues') ? '#dc3545' : '#28a745'
          output += "<div style='margin-left: #{indent}px; padding: 5px;'>"
          output += "<strong style='color: #007BFF;'>#{key}:</strong> "
          output += "<span style='color: #{color};'>#{value}</span></div>"
        end
      end
      output
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