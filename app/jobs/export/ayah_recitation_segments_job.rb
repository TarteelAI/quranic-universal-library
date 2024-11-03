module Export
  class AyahRecitationSegmentsJob < ApplicationJob
    STORAGE_PATH = "#{Rails.root}/tmp/exported_segments"

    def perform(file_name:, table_name: 'ayah_timing', user_id:, recitations_ids: [])
      require 'sqlite3'
      file_path = prepare_file_paths(file_name)
      export_sqlite_db(file_path, table_name, recitations_ids)
      send_email(file_path, user_id)
    end

    protected

    def prepare_file_paths(file_name)
      file_path = "#{STORAGE_PATH}/#{Time.now.to_i}"
      FileUtils::mkdir_p file_path

      "#{file_path}/#{file_name}"
    end

    def export_sqlite_db(file_name, table_name, recitations_ids)
      recitations = load_recitations(recitations_ids)
      db = SQLite3::Database.new(file_name)
      table_name = table_name.gsub(/[^0-9a-z_]/i, '_').gsub('__', '_').first(40)

      columns = "label, reciter, surah_number, ayah_number, timings"
      db.execute("CREATE TABLE #{table_name}(label STRING, reciter INTEGER, surah_number INTEGER, ayah_number INTEGER, timings TEXT)")

      recitations.each do |recitation|
        tarteel_key = recitation.tarteel_key
        segments_data = recitation.audio_files.order("verse_id ASC").map do |file|
          [tarteel_key, recitation.id, file.chapter_id, file.verse_number, file.segment_data.to_s]
        end
        placeholders = segments_data.map { "(?, ?, ?, ?, ?)" }.join(", ")
        db.execute("INSERT INTO #{table_name} (#{columns}) VALUES #{placeholders}", segments_data.flatten)
      end
      db.close
    end

    def send_email(file_path, user_id)
      admin = User.find(user_id)

      # zip the file
      `bzip2 #{file_path}`

      zip_path = "#{file_path}.bz2"

      DeveloperMailer.notify(
        to: admin.email,
        subject: "Ayah recitation segments dump file",
        message: email_body(admin),
        file_path: zip_path
      ).deliver_now
    end

    def email_body(user)
      <<-EMAIL
Assalamu Alaikum #{user.name},

Attached are the exported audio timing db for your selected recitations. Please find the details in the attached SQLite database.

If you have any questions or need further assistance, feel free to reach out.

Best regards,
      EMAIL
    end

    def load_recitations(recitations_ids)
      if recitations_ids == ['tarteel-reciters']
        tag = Tag.where(name: 'Tarteel recitation').first_or_create
        resources = ResourceContent
                      .recitations
                      .one_verse
                      .joins(:resource_tags)
                      .where(resource_tags: { tag_id: tag.id })

        Recitation.where(resource_content: resources)
      else
        Recitation.where(id: recitations_ids.map(&:to_i))
      end
    end
  end
end