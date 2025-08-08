module V1
  module Audio
    class SegmentPresenter < ApplicationPresenter
      def surah_audio
        ::Audio::ChapterAudioFile.where(
          audio_recitation_id: recitation_id,
          chapter: chapter_id
        ).first
      end

      def ayah_segments
        range = [
          params[:from].to_i,
          (params[:to] || params[:from].to_i + per_page).to_i
        ] if lookahead.selects?(:from)

        segments = finder.ayah_segments(
          recitation: recitation_id,
          chapter: chapter_id,
          ayah_range: range
        )

        @pagination = finder.pagination
        segments
      end

      def surah_segments
        range = [
          params[:from].to_i,
          (params[:to] || params[:from].to_i + per_page).to_i
        ] if lookahead.selects?(:from)

        segments = finder.surah_segments(
          recitation: recitation_id,
          chapter: chapter_id,
          ayah_range: range
        )

        @pagination = finder.pagination
        segments
      end

      protected

      def finder
        @finder ||= ::V1::SegmentFinder.new
      end

      def recitation_id
        params[:recitation_id]
      end

      def chapter_id
        params[:surah]
      end

      def ayah

      end
    end
  end
end