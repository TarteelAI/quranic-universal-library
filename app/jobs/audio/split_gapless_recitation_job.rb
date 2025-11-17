module Audio
  class SplitGaplessRecitationJob < ApplicationJob
    sidekiq_options retry: 0, backtrace: true
    STORAGE_PATH = "#{Rails.root}/data/audio"

    def perform(recitation_id:, host:, user_id:, surah: nil, ayah_from: nil, ayah_to: nil, divide_audio:, ayah_recitation_id: nil, create_ayah_recitation: false)
      base_path = prepare_file_paths(recitation_id)
      surah_recitation = Audio::Recitation.find(recitation_id)
      ayah_recitation = find_or_create_ayah_recitation(ayah_recitation_id, surah_recitation)

      if create_ayah_recitation
        create_audio_files(ayah_recitation, host)
      end

      surah = surah.to_i if surah.present?
      create_ayah_segments(surah_recitation, ayah_recitation, surah)
      detect_repeated_segments(ayah_recitation, surah)

      if divide_audio
        split_audio_files(
          base_path,
          surah_recitation,
          surah: surah,
          ayah_from: ayah_from,
          ayah_to: ayah_to
        )

        #send_email(base_path, user_id, recitation_id)
      end
    end

    protected

    def find_or_create_ayah_recitation(ayah_recitation_id, audio_recitation)
      if ayah_recitation_id.blank?
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
      else
        ayah_recitation = Recitation.find(ayah_recitation_id)
      end

      ayah_recitation
    end

    def create_audio_files(ayah_recitation, host)
      return if AudioFile.where(recitation_id: ayah_recitation.id).count >= Verse.count

      Verse.unscoped.order('verse_index asc').each do |verse|
        audio_file = AudioFile.where(verse: verse, recitation_id: ayah_recitation.id).first_or_initialize
        chapter_id = verse.chapter_id
        verse_number = verse.verse_number
        audio_file.chapter_id = chapter_id
        audio_file.verse_number = verse_number
        audio_file.verse_key = verse.verse_key

        audio_file.url = "#{host}/#{chapter_id.to_s.rjust(3, '0')}#{verse_number.to_s.rjust(3, '0')}.mp3"
        audio_file.save(validate: false)
      end
    end

    def detect_repeated_segments(ayah_recitation, chapter_id)
      AudioSegment::AyahByAyah.new(ayah_recitation).track_repetition(chapter_id: chapter_id)
    end

    def split_audio_files(base_path, audio_recitation, surah:, ayah_from:, ayah_to:)
      audio_split = Audio::SplitGaplessAudio.new(
        audio_recitation.id,
        base_path
      )

      if surah.present?
        audio_split.split_surah(
          surah.to_i,
          ayah_from: ayah_from,
          ayah_to: ayah_to
        )
      else
        1.upto(114).each do |chapter|
          audio_split.split_surah(chapter)
        end
      end
    end

    def create_ayah_segments(surah_recitation, ayah_recitation, chapter_id)
      segment_split = Audio::SplitGaplessSegment.new(
        surah_recitation.id,
        ayah_recitation.id
      )

      if chapter_id.present?
        segment_split.split_surah(chapter_id)
      else
        1.upto(114).each do |chapter_id|
          segment_split.split_surah(chapter_id)
        end
      end
    end

    def prepare_file_paths(recitation_id)
      file_path = "#{STORAGE_PATH}/#{recitation_id}/mp3"
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

    def send_email(file_path, user_id, recitation_id)
      recitation = Audio::Recitation.find(recitation_id)
      user = User.find(user_id)

      # zip the file
      `bzip2 #{file_path}/ayah-by-ayah`

      zip_path = "#{file_path}/ayah-by-ayah.bz2"

      DeveloperMailer.notify(
        to: user.email,
        subject: "#{recitation.name} audio files",
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