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
        issues.concat(word_order_issues(segment))
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

      issues = []

      earliest_start = min_word_start(segment)
      if earliest_start && from > earliest_start
        diff = from - earliest_start
        suggestion = "Move #{segment.verse_key} start earlier by #{diff} ms (from #{from} to #{earliest_start} ms) so the ayah starts on or before its first word."
        issues << issue(segment, "#{segment.verse_key} ayah starts at #{from} which is after its earliest word starting at #{earliest_start}.", 'bg-danger', 'ayah_timing', suggestion: suggestion)
      end

      latest_end = max_word_end(segment)
      if latest_end && to < latest_end
        diff = latest_end - to
        suggestion = "Extend #{segment.verse_key} end later by #{diff} ms (from #{to} to #{latest_end} ms) so the ayah covers its last word."
        issues << issue(segment, "#{segment.verse_key} ayah ends at #{to} which is before its latest word ending at #{latest_end}.", 'bg-warning', 'ayah_timing', suggestion: suggestion)
      end

      issues
    end

    def ayah_boundary_issues(segment, lookup)
      return [] if blank?(segment.timestamp_to)

      next_ayah = lookup[[segment.chapter_id, segment.verse_number + 1]]
      return [] unless next_ayah

      next_start = [next_ayah.timestamp_from, min_word_start(next_ayah)].compact.map(&:to_i).min
      return [] if next_start.nil?

      if segment.timestamp_to > next_start
        overlap = segment.timestamp_to - next_start
        suggestion = "Overlap is #{overlap} ms. Reduce #{segment.verse_key} end by #{overlap} ms (from #{segment.timestamp_to} to #{next_start} ms), or push #{next_ayah.verse_key} start later by #{overlap} ms (from #{next_start} to #{segment.timestamp_to} ms)."
        [issue(segment, "#{segment.verse_key} ends at #{segment.timestamp_to} which overlaps the next ayah #{next_ayah.verse_key} starting at #{next_start}.", 'bg-danger', 'ayah_overlap', suggestion: suggestion)]
      elsif next_start - segment.timestamp_to > AYAH_GAP_THRESHOLD_MS
        gap = next_start - segment.timestamp_to
        excess = gap - AYAH_GAP_THRESHOLD_MS
        suggestion = "Silent gap is #{gap} ms — #{excess} ms over the #{AYAH_GAP_THRESHOLD_MS} ms limit. Extend #{segment.verse_key} end later or move #{next_ayah.verse_key} start earlier by at least #{excess} ms to close the gap."
        [issue(segment, "#{segment.verse_key} ends at #{segment.timestamp_to} but the next ayah #{next_ayah.verse_key} starts at #{next_start} — #{gap} ms gap (max allowed is #{AYAH_GAP_THRESHOLD_MS} ms).", 'bg-warning', 'ayah_gap', suggestion: suggestion)]
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

    def word_order_issues(segment)
      word_numbers = segment.word_segments.map { |word| word[0].to_i }
      return [] if word_numbers.empty?

      issues = []
      words_count = segment.words_count.to_i

      if word_numbers.first != 1
        issues << issue(segment, "#{segment.verse_key} word segments start at word #{word_numbers.first} but should start at word 1.", 'bg-danger', 'word_order')
      end

      if words_count.positive? && word_numbers.last != words_count
        issues << issue(segment, "#{segment.verse_key} word segments end at word #{word_numbers.last} but the ayah has #{words_count} words — a repeat is incomplete.", 'bg-danger', 'word_order')
      end

      if words_count.positive?
        missing = (1..words_count).to_a - word_numbers.uniq
        if missing.any?
          issues << issue(segment, "#{segment.verse_key} has no segment for word(s) #{missing.join(', ')}.", 'bg-danger', 'word_order')
        end
      end

      word_numbers.each_cons(2) do |previous_number, current_number|
        if current_number > previous_number + 1
          issues << issue(segment, "#{segment.verse_key} word segments jump from word #{previous_number} to word #{current_number} (gap in sequence).", 'bg-danger', 'word_order')
        end
      end

      issues
    end

    def word_timing_issues(segment)
      issues = []
      previous_word_end = nil

      segment.word_segments.each do |word_segment|
        from = word_segment[1]
        to = word_segment[2]
        position = word_segment[0]

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

        suggestion = "Extend #{last_segment.verse_key} end by #{gap} ms (from #{last_segment.timestamp_to} to #{duration} ms) to cover the tail, or trim the extra audio if it is silence."
        issues << issue(last_segment, "Audio file ##{audio_file_id} is #{duration} ms but the last segment (#{last_segment.verse_key}) ends at #{last_segment.timestamp_to} ms — #{gap} ms (#{(gap / 1000.0).round}s) of audio after the last ayah is unsegmented.", 'bg-danger', 'trailing_gap', suggestion: suggestion)
      end

      issues
    end

    def min_word_start(segment)
      starts = segment.word_segments.map { |word| word[1] }.select { |value| present?(value) }.map(&:to_i)
      starts.min
    end

    def max_word_end(segment)
      ends = segment.word_segments.map { |word| word[2] }.select { |value| present?(value) }.map(&:to_i)
      ends.max
    end

    def issue(segment, text, severity, category, suggestion: nil)
      data = { key: segment.verse_key, text: text, severity: severity, category: category }
      data[:suggestion] = suggestion if suggestion
      data
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
