class GenerateSurahAudioFilesJob < ApplicationJob
  queue_as :default

  def perform(recitation_id, meta: false, chapter: nil)
    service = Audio::GenerateSurahAudio.new(recitation_id)
    service.generate_audio_files(chapter: chapter, meta: meta)
  end
end