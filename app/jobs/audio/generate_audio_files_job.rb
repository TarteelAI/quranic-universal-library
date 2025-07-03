module Audio
  class GenerateAudioFilesJob < ApplicationJob
    def perform(recitation)
      audio_file_service = Audio::GenerateAudioFile.new(recitation: recitation)
      audio_file_service.generate_audio_files
    end
  end
end

