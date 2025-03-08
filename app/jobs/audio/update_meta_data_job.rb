module Audio
  class UpdateMetaDataJob < ApplicationJob
    def perform(recitation, options={})
      audio_meta_service = Audio::AudioFileMetaData.new(recitation: recitation)
      audio_meta_service.update_meta_data(options)
    end
  end
end