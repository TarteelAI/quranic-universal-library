module Audio
  class GenerateAudioFile
    attr_reader :recitation,
                :resource_content,
                :base_url,
                :relative_path

    def initialize(recitation:)
      @recitation = recitation
      @resource_content = @recitation.get_resource_content
      @base_url = @resource_content.meta_value("audio-cdn-url") || "https://download.quranicaudio.com"

      path = recitation.relative_path || @recitation.name.downcase.underscore
      @relative_path = path.delete_prefix('/').delete_suffix('/')
    end

    def generate_audio_files
      if recitation.one_ayah?
        generate_ayah_audio_files
      else
        generate_surah_audio_files
      end
    end

    protected

    def generate_ayah_audio_files
      Verse.order('verse_index').each do |v|
        create_ayah_audio_file(verse: v)
      end
    end

    def generate_surah_audio_files
      1.upto(114).each do |chapter_number|
        create_surah_audio_file(chapter_number: chapter_number)
      end
    end

    def create_ayah_audio_file(verse:)
      audio_file = AudioFile.where(
        recitation_id: recitation.id,
        verse_id: verse.id
      ).first_or_initialize

      url = audio_file.url

      if url.blank?
        filename = "#{verse.chapter_id.to_s.rjust 3, '0'}#{verse.verse_number.to_s.rjust 3, '0'}.#{recitation.audio_format}"
        url = "#{base_url}/#{relative_path}/#{filename}"
      end

      audio_file.chapter_id = verse.chapter_id
      audio_file.hizb_number = verse.hizb_number
      audio_file.juz_number = verse.juz_number
      audio_file.manzil_number = verse.manzil_number
      audio_file.verse_number = verse.verse_number
      audio_file.page_number = verse.page_number
      audio_file.rub_el_hizb_number = verse.rub_el_hizb_number
      audio_file.ruku_number = verse.ruku_number
      audio_file.verse_key = verse.verse_key

      audio_file.url = url
      audio_file.format = recitation.audio_format
      audio_file.is_enabled = true
      audio_file.save(validate: false)

      audio_file
    end

    def create_surah_audio_file(chapter_number:)
      audio_file = find_or_create_surah_audio_file(chapter_number: chapter_number)
      format = audio_file.audio_format || recitation.audio_format
      format = format.split(',').first

      audio_file.attributes = {
        chapter_id: chapter_number,
        file_name: "#{chapter_number.to_s.rjust 3, '0'}.#{format}",
        format: format
      }
      audio_file.save(validate: false)
    end

    def find_or_create_surah_audio_file(chapter_number:)
      audio = recitation
                .chapter_audio_files
                .where(chapter_id: chapter_number)
                .first_or_initialize
      url = audio.audio_url

      if url.blank?
        name = chapter_number.to_s.rjust 3, '0'
        url = "#{base_url}/#{relative_path}/#{name}.#{recitation.audio_format}"
      end
      audio.audio_url = url

      audio
    end
  end
end