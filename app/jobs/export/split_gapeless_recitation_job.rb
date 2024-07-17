module Export
  class SplitGapelessRecitationJob < ApplicationJob
    STORAGE_PATH = "#{Rails.root}/tmp/gapped_audio"

    def perform(audio_recitation_id, host, user_id)
      base_path = prepare_file_paths

      create_ayah_recitation_audio_files(audio_recitation_id, host)
      split_audio_files(base_path, audio_recitation_id)

      send_email(file_path, user_id)
    end

    protected
    def create_ayah_recitation_audio_files(audio_recitation_id, host)
      audio_recitation = Audio::Recitation.find(audio_recitation_id)
      resource_content = ResourceContent.recitations.one_verse.new
      resource_content.name = audio_recitation.name
      resource_content.save(validate: false)

      ayah_recitation = Recitation.new(
        reciter_name: audio_recitation.name,
        reciter_id: audio_recitation.reciter_id,
        qirat_type_id: audio_recitation.qirat_type_id
      )
      ayah_recitation.resource_content_id = resource_content.id
      ayah_recitation.save(validate: false)

      Verse.unscoped.order('verse_index asc').each do |verse|
        audio_file = AudioFile.where(verse: verse, recitation_id: ayah_recitation.id).first_or_initialize
        chapter_id = verse.chapter_id
        verse_number = verse.verse_number
        audio_file.url = "#{host}/#{chapter_id.to_s.rjust(3, '0')}#{verse_number.to_s.rjust(3, '0')}.mp3"
        audio_file.save(validate: false)
      end

      segment_split = Audio::SplitGapelessSegment.new(audio_recitation_id, ayah_recitation.id)

      1.upto(114).each do |chapter_id|
        segment_split.split_surah(chapter_id)
      end
    end

    def split_audio_files(base_path, audio_recitation_id)
      audio_split = Audio::SplitGapelessAudio.new(audio_recitation_id, base_path)

      1.upto(114).each do |chapter|
        audio_split.split_surah(chapter)
      end
    end

    def prepare_file_paths
      file_path = "#{STORAGE_PATH}/#{Time.now.to_i}/audio_files"
      FileUtils::mkdir_p file_path

      file_path
    end

    def export_sqlite_db(file_name, table_name, recitations_ids)
      recitations = load_recitations(recitations_ids)
      db = SQLite3::Database.new(file_name)
      columns = "label, reciter, surah_number, ayah_number, timings"
      db.execute("CREATE TABLE #{table_name}(label STRING, reciter INTEGER,surah_number INTEGER,ayah_number INTEGER, timings TEXT)")

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
      user = User.find(user_id)

      # zip the file
      `bzip2 #{file_path}`

      zip_path = "#{file_path}.bz2"

      DeveloperMailer.notify(
        to: user.email,
        subject: "Ayah recitation segments dump file",
        message: email_body(user),
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