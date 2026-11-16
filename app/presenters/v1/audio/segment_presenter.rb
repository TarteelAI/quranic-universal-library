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

      # The loaded ayahs as { segment:, passes: } (see Audio::Segment#recitation_passes).
      def surah_segment_passes
        @surah_segment_passes ||= begin
          list = surah_segments.to_a
          returns = ::Audio::Segment.cross_ayah_returns_for(list)
          list.map { |segment| { segment: segment, passes: segment.recitation_passes(returns[[segment.chapter_id, segment.verse_number]]) } }
        end
      end

      # Every pass in recitation order: [[verse_key, pass, time_from, time_to], ...].
      # pass 0 is the ayah's `segments`, pass N is `repeats[N - 1]`.
      def surah_timeline
        surah_segment_passes.flat_map do |entry|
          entry[:passes].map { |pass| [entry[:segment].verse_key, pass[:pass], pass[:time_from], pass[:time_to]] }
        end.each_with_index.sort_by { |row, i| [row[2].to_i, i] }.map(&:first)
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
