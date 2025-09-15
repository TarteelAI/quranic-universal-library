module V1
  module Audio
    class RecitationPresenter < ApplicationPresenter
      def ayah_recitations
        ::Recitation
          .approved
          .includes(:recitation_style, :qirat_type)
      end

      def surah_recitations
        ::Audio::Recitation
          .approved
          .includes(:recitation_style, :qirat_type)
      end

      def surah_recitation
        surah_recitations.find(params[:id])
      end

      def ayah_recitation
        ayah_recitations.find(params[:id])
      end

      def wav_manifest
        manifest = {}
        chapter_audio_files = ::Audio::ChapterAudioFile
                                .where(audio_recitation_id: params[:id])
                                .order('chapter_id ASC')

        chapter_audio_files.each do |audio_file|
          chapter_id = audio_file.chapter_id
          parts = audio_file.meta_value('wav_parts') || []
          manifest[chapter_id] = parts
        end

        manifest
      end
    end
  end
end