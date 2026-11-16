module V1
  module Audio
    class TranscriptPresenter < ApiPresenter
      DEFAULT_SCRIPT = 'text_imlaei'.freeze

      ALLOWED_SCRIPTS = [
        'text_qpc_hafs',
        'text_imlaei',
        'text_imlaei_simple',
        'text_digital_khatt'
      ].freeze

      def recitation
        @recitation ||= ::Audio::Recitation.approved.find(params[:id])
      end

      def requested_quran_script
        return @script if defined?(@script)

        requested = params[:script].to_s.strip.downcase
        return @script = DEFAULT_SCRIPT if requested.blank?

        invalid_script(requested) unless ALLOWED_SCRIPTS.include?(requested)

        @script = requested
      end

      def segments
        return @segments if defined?(@segments)

        range = [
          params[:from].to_i,
          (params[:to] || params[:from].to_i + per_page).to_i
        ] if lookahead.selects?(:from)

        list = finder.surah_segments(
          recitation: recitation.id,
          chapter: chapter_id,
          ayah_range: range
        ).includes(verse: :words).to_a

        @pagination = finder.pagination

        @segments = list
      end

      def as_array?
        return @as_array if defined?(@as_array)

        @as_array = ::ActiveModel::Type::Boolean.new.cast(params[:array]).present?
      end

      def text_for(segment)
        segment.transcript(script: requested_quran_script, as_array: as_array?)
      end

      # Every recitation pass of the loaded ayahs, in recitation order:
      # [[key, pass, time_from, time_to, text], ...]. An ayah the reciter came
      # back to after other ayahs has extra passes keyed "70:27:r1", "70:27:r2".
      def transcript_entries
        return @transcript_entries if defined?(@transcript_entries)

        returns = ::Audio::Segment.cross_ayah_returns_for(segments)
        entries = segments.flat_map do |segment|
          segment.transcript_passes(
            returns[[segment.chapter_id, segment.verse_number]],
            script: requested_quran_script,
            as_array: as_array?
          )
        end
        entries = entries.each_with_index.sort_by { |entry, i| [entry[2].to_i, i] }.map(&:first) if returns.present?

        @transcript_entries = entries
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

      def chapter_id
        return @chapter_id if defined?(@chapter_id)

        value = params[:chapter] || params[:surah]
        number = value.to_i
        invalid_chapter(value.presence || 'Missing') unless (1..114).cover?(number)

        @chapter_id = number
      end

      def invalid_script(value)
        raise ::Api::BadRequest.new(
          "#{value} is not a valid script. Supported scripts are #{ALLOWED_SCRIPTS.join(', ')}."
        )
      end
    end
  end
end
