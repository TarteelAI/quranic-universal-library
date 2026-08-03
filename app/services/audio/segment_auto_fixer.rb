# frozen_string_literal: true

require 'set'

module Audio
  class SegmentAutoFixer
    Result = Struct.new(:before, :after, :fixed, :skipped, :changes, :pending, :changed_segments, keyword_init: true)

    AYAH_GAP_BUFFER_MS = 400

    def initialize(segments, expected_verses_count: 6236)
      @segments = segments.to_a
      @expected_verses_count = expected_verses_count
    end

    def run
      before_issues = validate(@segments)
      before = count_by_category(before_issues)
      @reported = reported_map(before_issues)
      @fixed = Hash.new(0)
      @skipped = Hash.new(0)
      @changes = []

      @segments.group_by(&:chapter_id).each_value do |chapter_segments|
        ordered = chapter_segments.sort_by(&:verse_number)

        ordered.each_with_index { |segment, index| fix_ayah_first_word(segment, index.positive? ? ordered[index - 1] : nil) }
        ordered.each_cons(2) { |current, following| fix_ayah_overlap(current, following) }
        ordered.each_cons(2) { |current, following| fix_ayah_gap(current, following) }
        ordered.each { |segment| fix_word_overlap(segment) }
      end

      changed = @segments.select(&:changed?)
      pending = validate(@segments)
      after = count_by_category(pending)

      Result.new(
        before: before,
        after: after,
        fixed: @fixed,
        skipped: @skipped,
        changes: @changes,
        pending: pending,
        changed_segments: changed
      )
    end

    private

    def record_change(segment, category, target, old_value, new_value)
      @changes << {
        category: category,
        verse_key: segment.verse_key,
        chapter_id: segment.chapter_id,
        verse_number: segment.verse_number,
        target: target,
        old_value: old_value,
        new_value: new_value
      }
    end

    def fix_ayah_first_word(segment, previous)
      return unless reported?('ayah_timing', segment.verse_key)

      from = segment.timestamp_from
      to = segment.timestamp_to
      return if blank?(from) || blank?(to)

      first_word = segment.get_segments(drop_metadata: true).find { |word| word[0].to_i == 1 }
      return unless first_word && present?(first_word[1])

      first_word_start = first_word[1].to_i
      return unless from > first_word_start

      if first_word_start >= to
        @skipped['ayah_timing'] += 1
        return
      end

      previous_end = previous && present?(previous.timestamp_to) ? previous.timestamp_to : nil

      if previous_end && first_word_start <= previous_end
        new_previous_to = first_word_start - 1
        if new_previous_to > previous.timestamp_from.to_i
          record_change(previous, 'ayah_timing', 'Ayah end trimmed to accommodate next ayah first word (timestamp_to)', previous_end, new_previous_to)
          previous.set_timing(previous.timestamp_from, new_previous_to, previous.verse)
          record_change(segment, 'ayah_timing', 'Ayah start (timestamp_from)', from, first_word_start)
          segment.set_timing(first_word_start, to, segment.verse)
          @fixed['ayah_timing'] += 1
        else
          @skipped['ayah_timing'] += 1
        end
        return
      end

      record_change(segment, 'ayah_timing', 'Ayah start (timestamp_from)', from, first_word_start)
      segment.set_timing(first_word_start, to, segment.verse)
      @fixed['ayah_timing'] += 1
    end

    def fix_ayah_overlap(current, following)
      return unless reported?('ayah_overlap', current.verse_key)

      current_to = current.timestamp_to
      following_from = following.timestamp_from
      return if blank?(current_to) || blank?(following_from)
      return unless current_to > following_from

      # Determine if the overlap is caused by following.timestamp_from being set too early:
      # if current's last word ends before following's first word starts (words are sequential),
      # fix by moving following's start rather than trimming current's end.
      first_word = following.get_segments(drop_metadata: true).find { |w| w[0].to_i == 1 }
      last_word = current.get_segments(drop_metadata: true).select { |w| present?(w[2]) }.max_by { |w| w[0].to_i }

      first_word_start = first_word && present?(first_word[1]) ? first_word[1].to_i : nil
      last_word_end = last_word ? last_word[2].to_i : nil

      words_sequential = first_word_start && (
        (last_word_end && first_word_start >= last_word_end) ||
        first_word_start >= current_to
      )

      if words_sequential
        new_following_from = if last_word_end && first_word_start >= last_word_end
          [first_word_start - AYAH_GAP_BUFFER_MS, last_word_end].max
        else
          first_word_start - AYAH_GAP_BUFFER_MS
        end

        if new_following_from > following.timestamp_from.to_i
          # Derive effective timestamp_to for following: use existing value if valid,
          # otherwise fall back to the last word's end time (handles cases where both
          # timestamp_from and timestamp_to were set to wrong early values).
          existing_to = present?(following.timestamp_to) ? following.timestamp_to.to_i : nil
          effective_to = (existing_to && existing_to > new_following_from) ? existing_to : nil

          unless effective_to
            last_word_following = following.get_segments(drop_metadata: true)
                                           .select { |w| present?(w[2]) }
                                           .max_by { |w| w[0].to_i }
            effective_to = last_word_following ? last_word_following[2].to_i : nil
          end

          if effective_to && effective_to > new_following_from
            record_change(following, 'ayah_overlap', 'Ayah start corrected via first word (timestamp_from)', following_from, new_following_from)
            if existing_to.nil? || existing_to != effective_to
              record_change(following, 'ayah_overlap', 'Ayah end corrected via last word (timestamp_to)', following.timestamp_to, effective_to)
            end
            following.set_timing(new_following_from, effective_to, following.verse)

            if current_to >= new_following_from
              new_current_to = new_following_from - 1
              if new_current_to > current.timestamp_from.to_i
                record_change(current, 'ayah_overlap', 'Ayah end trimmed after next ayah start correction (timestamp_to)', current_to, new_current_to)
                current.set_timing(current.timestamp_from, new_current_to, current.verse)
              end
            end

            @fixed['ayah_overlap'] += 1
            return
          end
        end
      end

      new_to = following_from - 1

      if new_to > current.timestamp_from.to_i
        record_change(current, 'ayah_overlap', 'Ayah end (timestamp_to)', current_to, new_to)
        current.set_timing(current.timestamp_from, new_to, current.verse)
        @fixed['ayah_overlap'] += 1
      else
        @skipped['ayah_overlap'] += 1
      end
    end

    def fix_ayah_gap(current, following)
      return unless reported?('ayah_gap', current.verse_key)

      current_to = current.timestamp_to
      following_from = following.timestamp_from
      return if blank?(current_to) || blank?(following_from)

      gap = following_from - current_to
      return unless gap > Audio::SegmentValidator::AYAH_GAP_THRESHOLD_MS

      new_to = following_from - AYAH_GAP_BUFFER_MS

      if new_to > current.timestamp_from.to_i
        record_change(current, 'ayah_gap', 'Ayah end extended to close gap (timestamp_to)', current_to, new_to)
        current.set_timing(current.timestamp_from, new_to, current.verse)
        @fixed['ayah_gap'] += 1
      else
        @skipped['ayah_gap'] += 1
      end
    end

    def fix_word_overlap(segment)
      return unless reported?('word_overlap', segment.verse_key)

      raw = segment.segments
      return if blank?(raw)

      words = raw.map(&:dup)
      changed = false
      previous_index = nil

      words.each_with_index do |word, index|
        from = word[1]
        to = word[2]
        next if blank?(from) || blank?(to)

        from = from.to_i

        if previous_index
          previous_word = words[previous_index]
          previous_from = previous_word[1].to_i
          previous_to = previous_word[2].to_i

          if from < previous_to
            new_previous_to = from - 1

            if new_previous_to > previous_from
              record_change(segment, 'word_overlap', "Word #{previous_word[0]} end", previous_to, new_previous_to)
              previous_word[2] = new_previous_to
              @fixed['word_overlap'] += 1
              changed = true
            else
              @skipped['word_overlap'] += 1
            end
          end
        end

        previous_index = index
      end

      if changed
        segment.segments = words
        segment.segments_count = words.size
      end
    end

    def validate(segments)
      Audio::SegmentValidator.new(segments, expected_verses_count: @expected_verses_count).validate
    end

    def count_by_category(issues)
      issues.group_by { |issue| issue[:category] }.transform_values(&:size)
    end

    def reported_map(issues)
      issues.each_with_object({}) do |issue, map|
        next unless issue[:key]

        (map[issue[:category]] ||= Set.new) << issue[:key]
      end
    end

    def reported?(category, verse_key)
      set = @reported[category]
      set ? set.include?(verse_key) : false
    end

    def present?(value)
      !blank?(value)
    end

    def blank?(value)
      value.nil? || (value.respond_to?(:empty?) && value.empty?) || value == ''
    end
  end
end
