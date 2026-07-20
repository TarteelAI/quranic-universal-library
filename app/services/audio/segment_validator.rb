# frozen_string_literal: true

module Audio
  class SegmentValidator
    TRAILING_GAP_THRESHOLD_MS = 1000
    AYAH_GAP_THRESHOLD_MS = 2000

    SegmentData = Struct.new(
      :verse_key,
      :chapter_id,
      :verse_number,
      :timestamp_from,
      :timestamp_to,
      :words_count,
      :word_segments,
      :audio_file_id,
      :audio_duration_ms,
      keyword_init: true
    )

    def self.from_record(record)
      SegmentData.new(
        verse_key: record.verse_key,
        chapter_id: record.chapter_id,
        verse_number: record.verse_number,
        timestamp_from: record.timestamp_from,
        timestamp_to: record.timestamp_to,
        words_count: record.verse&.words_count.to_i,
        word_segments: record.get_segments(drop_metadata: true),
        audio_file_id: record.audio_file_id,
        audio_duration_ms: record.audio_file&.duration_ms
      )
    end

    # segments: an enumerable of Audio::Segment records or SegmentData structs.
    # expected_verses_count: how many ayahs should be segmented (chapter.verses_count or 6236).
    def initialize(segments, expected_verses_count:)
      @segments = segments.map { |segment| segment.is_a?(SegmentData) ? segment : self.class.from_record(segment) }
      @expected_verses_count = expected_verses_count
    end

    def validate
      issues = []

      issues.concat(missing_segments_issues)

      lookup = {}
      @segments.each { |segment| lookup[[segment.chapter_id, segment.verse_number]] = segment }

      @segments.each do |segment|
        issues.concat(ayah_timing_issues(segment))
        issues.concat(ayah_boundary_issues(segment, lookup))
        issues.concat(word_count_issues(segment))
        issues.concat(word_timing_issues(segment))
      end

      issues.concat(trailing_gap_issues)

      issues
    end

    private

    def missing_segments_issues
      return [] if @expected_verses_count == @segments.size

      missing = @expected_verses_count - @segments.size
      [{
        text: "#{missing} ayahs don't have segments data. Total segments: #{@segments.size}",
        severity: 'bg-danger',
        category: 'missing_segments'
      }]
    end

    def ayah_timing_issues(segment)
      from = segment.timestamp_from
      to = segment.timestamp_to

      if blank?(to) || blank?(from)
        return [issue(segment, "#{segment.verse_key} timestamp from OR to is missing.", 'bg-danger', 'ayah_timing')]
      elsif to < from
        return [issue(segment, "#{segment.verse_key} timestamp to(#{to}) is less than timestamp from(#{from})", 'bg-danger', 'ayah_timing')]
      elsif to == from
        return [issue(segment, "#{segment.verse_key} ayah duration is 0 (timestamp to equals from at #{from}).", 'bg-danger', 'ayah_timing')]
      end

      first_word_segment = segment.word_segments.find { |word| word[0].to_i == 1 }
      if present?(from) && first_word_segment && present?(first_word_segment[1]) && from > first_word_segment[1].to_i
        return [issue(segment, "#{segment.verse_key} ayah starts at #{from} which is after its first word starting at #{first_word_segment[1]}.", 'bg-danger', 'ayah_timing')]
      end

      []
    end

    def ayah_boundary_issues(segment, lookup)
      return [] if blank?(segment.timestamp_to)

      next_ayah = lookup[[segment.chapter_id, segment.verse_number + 1]]
      return [] unless next_ayah && present?(next_ayah.timestamp_from)

      if segment.timestamp_to > next_ayah.timestamp_from
        [issue(segment, "#{segment.verse_key} ends at #{segment.timestamp_to} which overlaps the next ayah #{next_ayah.verse_key} starting at #{next_ayah.timestamp_from}.", 'bg-danger', 'ayah_overlap')]
      elsif next_ayah.timestamp_from - segment.timestamp_to > AYAH_GAP_THRESHOLD_MS
        gap = next_ayah.timestamp_from - segment.timestamp_to
        [issue(segment, "#{segment.verse_key} ends at #{segment.timestamp_to} but the next ayah #{next_ayah.verse_key} starts at #{next_ayah.timestamp_from} — #{gap} ms gap (max allowed is #{AYAH_GAP_THRESHOLD_MS} ms).", 'bg-warning', 'ayah_gap')]
      else
        []
      end
    end

    def word_count_issues(segment)
      issues = []
      words_count = segment.words_count.to_i
      segments_count = segment.word_segments.size
      missing_words = words_count - segments_count

      if missing_words > 0
        issues << issue(segment, "#{segment.verse_key} don't have segments for some words(#{missing_words} #{pluralize_word(missing_words)} missing).", 'bg-warning', 'missing_words')
      end

      if segments_count > (words_count + (words_count.to_f * 0.5))
        issues << issue(segment, 'Too many words are repeated, debug the repetition.', 'bg-info', 'repeated_words')
      end

      issues
    end

    def word_timing_issues(segment)
      issues = []
      previous_word_end = nil

      segment.word_segments.each_with_index do |word_segment, index|
        from = word_segment[1]
        to = word_segment[2]
        position = index + 1

        if blank?(to) || blank?(from)
          issues << issue(segment, "#{segment.verse_key}:#{position} timestamp to(#{to}) or from(#{from}) is missing", 'bg-warning', 'word_timing')
          next
        elsif to < from
          issues << issue(segment, "#{segment.verse_key}:#{position} timestamp to(#{to}) is less than timestamp from(#{from})", 'bg-warning', 'word_timing')
        elsif to == from
          issues << issue(segment, "#{segment.verse_key}:#{position} timestamp to(#{to}) is equal to from (#{from}). Word duration is 0", 'bg-warning', 'word_timing')
        end

        if previous_word_end && from < previous_word_end
          issues << issue(segment, "#{segment.verse_key}:#{position} starts at #{from} before the previous word ends at #{previous_word_end} (words overlap)", 'bg-warning', 'word_overlap')
        end

        if present?(segment.audio_duration_ms) && to > segment.audio_duration_ms
          issues << issue(segment, "#{segment.verse_key}:#{position} ends at #{to} which is past the audio duration (#{segment.audio_duration_ms} ms)", 'bg-warning', 'word_past_duration')
        end

        previous_word_end = to
      end

      issues
    end

    def trailing_gap_issues
      issues = []

      @segments.group_by(&:audio_file_id).each do |audio_file_id, file_segments|
        next if audio_file_id.nil?

        duration = file_segments.map(&:audio_duration_ms).compact.first.to_i
        next unless duration.positive?

        last_segment = file_segments.select { |segment| present?(segment.timestamp_to) }.max_by(&:timestamp_to)
        next if last_segment.nil?

        gap = duration - last_segment.timestamp_to
        next if gap <= TRAILING_GAP_THRESHOLD_MS

        issues << issue(last_segment, "Audio file ##{audio_file_id} is #{duration} ms but the last segment (#{last_segment.verse_key}) ends at #{last_segment.timestamp_to} ms — #{gap} ms (#{(gap / 1000.0).round}s) of audio after the last ayah is unsegmented.", 'bg-danger', 'trailing_gap')
      end

      issues
    end

    def issue(segment, text, severity, category)
      { key: segment.verse_key, text: text, severity: severity, category: category }
    end

    def present?(value)
      !blank?(value)
    end

    def blank?(value)
      value.nil? || (value.respond_to?(:empty?) && value.empty?) || value == ''
    end

    def pluralize_word(count)
      count == 1 ? 'word' : 'words'
    end
  end
end
