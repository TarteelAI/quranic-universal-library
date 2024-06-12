class VerseAudioDurationJob < GenerateSurahAudioFilesJob
  def perform(*)
    require 'wahwah'
    FileUtils.mkdir_p("tmp/audio_meta_data")

    AudioFile.where(duration: [nil, 0]).find_each do |audio_file|
      begin
        url = audio_file.audio_url
        meta_file = fetch_meta_data(url: url)
        meta = WahWah.open(meta_file)
        duration = calculate_duration(url: url) || meta.duration

        audio_file.update_column(:duration, duration)
      rescue Exception => e
        puts e.message
      end
    end
    clean_up
  end
end