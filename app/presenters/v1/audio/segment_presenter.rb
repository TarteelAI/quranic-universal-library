module V1
  module Audio
    class SegmentPresenter < ApiPresenter
      def surah_audio
        @surah_audio ||= ::Audio::ChapterAudioFile.where(
          audio_recitation_id: recitation_id,
          chapter_id: chapter_id
        ).first || missing_surah_audio
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
        @finder ||= ::V1::SegmentFinder.new(
          current_page: current_page,
          per_page: per_page
        )
      end

      def per_page
        items = params[:per_page].to_i.abs
        items = 10 if items.zero?
        [items, 286].min
      end

      def recitation_id
        params[:recitation_id]
      end

      def chapter_id
        return @chapter_id if defined?(@chapter_id)

        value = params[:chapter] || params[:surah]
        number = value.to_i
        invalid_chapter(value.presence || 'Missing') unless (1..114).cover?(number)

        @chapter_id = number
      end

      def missing_surah_audio
        raise ::Api::RecordNotFound.new(
          "No surah audio file found for recitation #{recitation_id} and chapter #{chapter_id}."
        )
      end
    end
  end
end
