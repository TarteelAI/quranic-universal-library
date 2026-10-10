module V1
  module Audio
    class TranscriptPresenter < ApiPresenter
      DEFAULT_SCRIPT = 'text_imlaei'.freeze

      ALLOWED_SCRIPTS = {
        text_qpc_hafs: true,
        text_imlaei: true,
        text_imlaei_simple: true,
        text_digital_khatt: true
      }.freeze

      def recitation
        @recitation ||= ::Audio::Recitation.approved.find(params[:id])
      end

      def requested_quran_script
        return @script if defined?(@script)

        requested = params[:script].to_s.strip.downcase
        return @script = DEFAULT_SCRIPT if requested.blank?

        invalid_script(requested) unless ALLOWED_SCRIPTS.key?(requested)

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
          "#{value} is not a valid script. Supported scripts are #{ALLOWED_SCRIPTS.keys.join(', ')}."
        )
      end
    end
  end
end
