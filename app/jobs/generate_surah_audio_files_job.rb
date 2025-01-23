class GenerateSurahAudioFilesJob < ApplicationJob
  queue_as :default

  def perform(recitation_id, meta: false, chapter: nil)
    require 'wahwah'
    recitation = Audio::Recitation.find(recitation_id)
    FileUtils.mkdir_p("tmp/audio_meta_data")

    if chapter
      create_file(chapter_number: chapter, recitation: recitation, force_update_meta: meta)
    else
      1.upto(114).each do |chapter_number|
        create_file(chapter_number: chapter_number, recitation: recitation, force_update_meta: meta)
      end
    end

    if (resource_content = recitation.get_resource_content)
      recitation.chapter_audio_files.update_all(resource_content_id: resource_content.id)
    end

    recitation.update(
      files_size: recitation.chapter_audio_files.reload.sum(:file_size),
      files_count: recitation.chapter_audio_files.count
    )

    clean_up
  end

  protected

  def create_file(chapter_number:, recitation:, force_update_meta:)
    audio_file = recitation
                   .chapter_audio_files
                   .where(chapter_id: chapter_number)
                   .first_or_initialize

    url = audio_file.audio_url || audio_url(chapter_number: chapter_number, recitation: recitation)
    meta_response = fetch_meta_data(url: url)

    if meta_response
      format = audio_file.format || recitation.format
      #TODO: implement multi format schema, we're now serving both mp3 and opus audio
      format = format.split(',').first

      audio_file.attributes = {
        chapter_id: chapter_number,
        file_name: "#{chapter_number.to_s.rjust 3, '0'}.#{format}",
        format: audio_file.format || recitation.format,
        audio_url: url,
        file_size: meta_response[:size]
      }
      audio_file.save(validate: false)
    end
    return unless force_update_meta

    audio_file.update_segment_percentile

    # wahwah would give more info
    file = meta_response[:file]
    meta = WahWah.open(file)
    duration = calculate_duration(url: url) || meta.duration

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
      File.open("tmp/audio_meta_data/#{tmp_file_name}", "wb") do |file|
        file << body
      end

      {
        file: "tmp/audio_meta_data/#{tmp_file_name}",
        size: request.response.header['content-length']
      }
    end
  end

  def audio_url(chapter_number:, recitation:)
    path = recitation.relative_path.delete_prefix('/').delete_suffix('/')
    "https://download.quranicaudio.com/#{path}/#{chapter_number}.#{recitation.format}"
  end

  def fetch_bytes(url, size)
    uri = URI(url)
    Net::HTTP.version_1_2 # make sure we use higher HTTP protocol version than 1.0

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    http.get(url, { 'Range' => "bytes=0-#{size}" })
  end

  def clean_up
    FileUtils.remove_dir("tmp/audio_meta_data")
  end
end