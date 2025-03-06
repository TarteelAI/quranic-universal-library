module Audio
  class GenerateSurahAudio
    attr_reader :recitation,
                :resource_content,
                :base_url,
                :tmp_dir

    def initialize(recitation_id)
      @recitation = Audio::Recitation.find(recitation_id)
      @resource_content = @recitation.get_resource_content

      @tmp_dir = "tmp/audio_meta_data/#{recitation.id}"
      FileUtils.mkdir_p(@tmp_dir)
      @base_url = @resource_content.meta_value("audio-cdn-url") || "https://download.quranicaudio.com"
    end

    def generate_audio_files(chapter: nil, meta: true)
      if chapter
        create_file(
          chapter_number: chapter,
          force_update_meta: meta
        )
      else
        1.upto(114).each do |chapter_number|
          create_file(
            chapter_number: chapter_number,
            force_update_meta: meta
          )
        end
      end

      update_stats
      clean_up
    end

    protected

    def update_stats
      recitation.chapter_audio_files.update_all(resource_content_id: resource_content.id)

      recitation.update(
        files_size: recitation.chapter_audio_files.reload.sum(:file_size),
        files_count: recitation.chapter_audio_files.count
      )
    end

    def create_file(chapter_number:, force_update_meta:)
      audio_file = find_or_create_audio_file(chapter_number: chapter_number)
      url = audio_file.audio_url
      meta_response = fetch_meta_data(url: url)

      if meta_response
        format = audio_file.format || recitation.format
        # TODO: implement multi format schema, we're now serving both mp3 and opus audio
        format = format.split(',').first

        audio_file.attributes = {
          chapter_id: chapter_number,
          file_name: "#{chapter_number.to_s.rjust 3, '0'}.#{format}",
          format: format,
          file_size: meta_response[:size]
        }
        audio_file.save(validate: false)
      end
      return unless force_update_meta

      audio_file.update_segment_percentile

      file = meta_response[:file]
      meta = WahWah.open(file)
      duration = meta.duration || calculate_duration(url: url)

      audio_file.attributes = {
        bit_rate: meta.bitrate,
        duration: duration,
        duration_ms: duration * 1000,
        mime_type: MIME::Types.type_for(file).first.content_type,
        meta_data: prepare_audio_meta_data(audio_file: audio_file, meta: meta, file: file)
      }

      audio_file.save(validate: false)
    end

    def prepare_audio_meta_data(audio_file:, meta:, file:)
      existing_meta = audio_file.meta_data || {}
      chapter = audio_file.chapter

      existing_meta.with_defaults_values({
                                           album: meta.album.presence || "Quran",
                                           genre: meta.genre.presence || "Quran",
                                           title: meta.title.presence || chapter.name_simple,
                                           track: "#{chapter.chapter_number}/114",
                                           artist: meta.artist.presence || audio_file.audio_recitation.name,
                                           year: meta.year
                                         })

      existing_meta[:comment] = 'https://qul.tarteel.ai/'
      existing_meta.to_h
    end

    def calculate_duration(url:)
      # ffmpeg -i https://download.quranicaudio.com/quran/abdullaah_3awwaad_al-juhaynee/001.mp3 2>&1 | egrep "Duration"

      result = `ffmpeg -i #{url} 2>&1 | egrep "Duration"`
      matched = result.match(/Duration:\s(?<h>(\d+)):(?<m>(\d+)):(?<s>(\d+))/)

      (matched[:h].to_i * 3600) + (matched[:m].to_i * 60) + matched[:s].to_i
    rescue Exception => e
      nil
    end

    def fetch_meta_data(url:)
      request = fetch_bytes(url, 2.megabyte)
      body = request.body

      if body.to_s.include?("Not Found")
        return false
      else
        tmp_file_name = "audio-#{Time.now.to_i}.mp3"
        File.open("#{tmp_dir}/#{tmp_file_name}", "wb") do |file|
          file << body
        end

        {
          file: "#{tmp_dir}/#{tmp_file_name}",
          size: request.response.header['content-length']
        }
      end
    end

    def fetch_bytes(url, size)
      uri = URI(url)
      Net::HTTP.version_1_2 # make sure we use higher HTTP protocol version than 1.0

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      http.get(url, { 'Range' => "bytes=0-#{size}" })
    end

    def find_or_create_audio_file(chapter_number:)
      audio = recitation
        .chapter_audio_files
        .where(chapter_id: chapter_number)
        .first_or_initialize

      url = audio.audio_url || generate_audio_url(chapter_number: chapter_number)
      audio.audio_url = url

      audio.save(validate: false)

      audio
    end

    def generate_audio_url(chapter_number:)
      path = recitation.relative_path.delete_prefix('/').delete_suffix('/')

      "#{base_url}/#{path}/#{chapter_number}.#{recitation.format}"
    end

    def clean_up
      FileUtils.remove_dir(tmp_dir)
    end
  end
end