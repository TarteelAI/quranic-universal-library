module Stt
  class SegmentImporter
    attr_reader :recitation, :timing_dir, :persist

    def initialize(reciter_id:, timing_dir: nil, persist: true)
      @recitation = Audio::Recitation.find(reciter_id)
      @timing_dir = Pathname.new(timing_dir.presence || Rails.root.join("data", "stt", reciter_id.to_s, "timing"))
      @persist = persist
      @aligner = SurahTranscriptAligner.allocate
    end

    def import(surah: nil)
      surah_numbers = surah.present? ? [surah.to_i] : available_surahs
      raise "No timing files found in #{timing_dir}" if surah_numbers.empty?

      summaries = surah_numbers.map do |surah_number|
        import_surah(surah_number)
      end

      update_recitation_stats if persist

      {
        surahs: summaries,
        imported_segments: summaries.sum { |summary| summary[:imported_segments] },
        total_verses: summaries.sum { |summary| summary[:total_verses] },
        issues_count: summaries.sum { |summary| summary[:issues].size }
      }
    end

    private

    def import_surah(surah_number)
      path = timing_file_path(surah_number)
      raise "Timing file not found: #{path}" unless File.exist?(path)

      timing_words = load_timing_words(path)
      verses = Verse.where(chapter_id: surah_number).includes(:actual_words).order(:verse_number)
      audio_file = persist ? find_or_create_audio_file(surah_number) : nil
      cursor = 0
      issues = []
      verse_payloads = []
      stt_tokens_norm = timing_words.map { |entry| entry[:normalized] }

      verses.each do |verse|
        canonical_raw, canonical_norm, canonical_chars = verse_tokens(verse)
        span = @aligner.send(
          :find_best_matching_ayah,
          stt_tokens_norm,
          canonical_norm,
          cursor,
          SurahTranscriptAligner::DEFAULT_WINDOW_SIZE,
          canonical_chars
        )

        span_words = matched_span_words(timing_words, span)
        aligned_words = align_words(canonical_norm, span_words)
        segments = build_segments(aligned_words)

        verse_payloads << {
          verse: verse,
          span: span,
          segments: segments
        }

        if segments.present?
        else
          issues << issue_payload(verse, span, [], "no_segments")
        end

        missing_words = ((1..verse.words_count).to_a - segments.map(&:first))
        if span[:score].to_f < 0.9 || missing_words.present?
          issues << issue_payload(verse, span, missing_words, "review")
        end

        if span[:start].to_i >= 0 && span[:end].to_i >= span[:start].to_i && span[:score].to_f.positive?
          cursor = [cursor, span[:end].to_i + 1].max
        end
      end

      normalize_timing_gaps!(verse_payloads)

      imported_segments = 0

      verse_payloads.each do |payload|
        next if payload[:segments].blank?

        persist_segment(
          audio_file,
          payload[:verse],
          payload[:segments],
          payload[:timestamp_from],
          payload[:timestamp_to]
        ) if persist
        imported_segments += 1
      end

      update_audio_file_stats(audio_file) if persist

      {
        surah: surah_number,
        imported_segments: imported_segments,
        total_verses: verses.size,
        issues: issues
      }
    end

    def available_surahs
      Dir.glob(timing_dir.join("*.json")).map do |path|
        File.basename(path, ".json").to_i
      end.sort
    end

    def timing_file_path(surah_number)
      timing_dir.join("#{surah_number}.json")
    end

    def load_timing_words(path)
      JSON.parse(File.read(path)).filter_map do |entry|
        raw_word = entry["word"].to_s
        normalized = @aligner.send(:normalize_word, raw_word, strip_diacritics: true)
        next if normalized.blank?
        next unless normalized.match?(SurahTranscriptAligner::ARABIC_LETTER_RE)

        {
          text: raw_word,
          normalized: normalized,
          start_ms: seconds_to_ms(entry["start"]),
          end_ms: seconds_to_ms(entry["end"])
        }
      end
    end

    def verse_tokens(verse)
      words = verse.actual_words.sort_by(&:position)

      canonical_raw = words.map do |word|
        text = @aligner.send(:get_word_text, word)
        @aligner.send(:remove_waqfs, text.to_s)
      end.compact_blank

      canonical_norm = canonical_raw.map do |word|
        @aligner.send(:normalize_word, word, strip_diacritics: true)
      end

      canonical_chars = canonical_norm.join.gsub(" ", "").codepoints

      [canonical_raw, canonical_norm, canonical_chars]
    end

    def matched_span_words(timing_words, span)
      start_index = span[:start].to_i
      end_index = span[:end].to_i
      return [] if start_index.negative? || end_index < start_index

      timing_words[start_index..end_index] || []
    end

    def align_words(canonical_norm, span_words)
      span_norm = span_words.map { |entry| entry[:normalized] }
      matcher = SurahTranscriptAligner::SequenceMatcher.new(a: canonical_norm, b: span_norm)
      aligned = []
      last_canonical_index = 0

      matcher.get_opcodes.each do |tag, i1, i2, j1, j2|
        if tag == "equal"
          common = [i2 - i1, j2 - j1].min
          common.times do |offset|
            canonical_index = i1 + offset
            span_index = j1 + offset
            aligned << { position: canonical_index + 1, entry: span_words[span_index], status: tag }
            last_canonical_index = canonical_index + 1
          end
        elsif tag == "replace"
          canonical_count = i2 - i1
          span_count = j2 - j1
          common = [canonical_count, span_count].min

          common.times do |offset|
            canonical_index = i1 + offset
            span_index = j1 + offset
            aligned << { position: canonical_index + 1, entry: span_words[span_index], status: tag }
            last_canonical_index = canonical_index + 1
          end

          (common...canonical_count).each do |offset|
            canonical_index = i1 + offset
            aligned << { position: canonical_index + 1, entry: nil, status: "missed" }
            last_canonical_index = canonical_index + 1
          end

          (common...span_count).each do |offset|
            span_index = j1 + offset
            aligned << { position: nil, entry: span_words[span_index], status: "extra" }
          end
        elsif tag == "delete"
          (i1...i2).each do |canonical_index|
            aligned << { position: canonical_index + 1, entry: nil, status: "missed" }
            last_canonical_index = canonical_index + 1
          end
        elsif tag == "insert"
          inserted_norm = span_norm[j1...j2] || []
          repeat_start = @aligner.send(:find_contextual_repeat, canonical_norm, inserted_norm, last_canonical_index)

          inserted_norm.each_with_index do |_value, offset|
            span_index = j1 + offset
            aligned << {
              position: repeat_start ? repeat_start + offset + 1 : nil,
              entry: span_words[span_index],
              status: repeat_start ? "repeat" : "extra"
            }
          end
        end
      end

      aligned
    end

    def build_segments(aligned_words)
      aligned_words.filter_map do |item|
        position = item[:position]
        entry = item[:entry]
        next if position.blank? || entry.blank?

        [position, entry[:start_ms], entry[:end_ms]]
      end
    end

    def persist_segment(audio_file, verse, segments, timestamp_from, timestamp_to)
      segment = Audio::Segment.where(
        verse_id: verse.id,
        chapter_id: verse.chapter_id,
        audio_file_id: audio_file.id,
        audio_recitation_id: recitation.id
      ).first_or_initialize

      segment.audio_file = audio_file
      segment.audio_recitation = recitation
      segment.verse = verse
      segment.set_timing(timestamp_from, timestamp_to, verse)
      segment.set_segments(segments)
      segment.relative_segments = segments.map do |position, start_ms, end_ms|
        [position, start_ms - timestamp_from, end_ms - timestamp_from]
      end
      segment.save(validate: false)
    end

    def find_or_create_audio_file(surah_number)
      audio_file = Audio::ChapterAudioFile.where(
        chapter_id: surah_number,
        audio_recitation_id: recitation.id
      ).first_or_initialize

      audio_file.save(validate: false) if audio_file.new_record?
      audio_file
    end

    def update_audio_file_stats(audio_file)
      audio_file.update_column(:segments_count, audio_file.audio_segments.count)
    end

    def update_recitation_stats
      recitation.update_columns(
        files_count: recitation.chapter_audio_files.count,
        segments_count: recitation.audio_segments.count
      )
    end

    def seconds_to_ms(value)
      (value.to_f * 1000).round
    end

    def normalize_timing_gaps!(verse_payloads)
      verse_payloads.each do |payload|
        segments = payload[:segments]
        next if segments.blank?

        normalize_word_gaps!(segments)
        payload[:timestamp_from] = segments.first[1]
        payload[:timestamp_to] = segments.last[2]
      end

      previous_payload = nil

      verse_payloads.each do |payload|
        next if payload[:segments].blank?

        if previous_payload
          gap = payload[:timestamp_from] - previous_payload[:timestamp_to]

          if gap > 200
            payload[:timestamp_from] -= 200
            previous_payload[:timestamp_to] = payload[:timestamp_from]
            previous_payload[:segments].last[2] = payload[:timestamp_from]
          end
        end

        previous_payload = payload
      end
    end

    def normalize_word_gaps!(segments)
      segments.each_cons(2) do |current_segment, next_segment|
        next unless next_segment[1] > current_segment[2]

        current_segment[2] = next_segment[1]
      end
    end

    def issue_payload(verse, span, missing_words, status)
      {
        verse_key: verse.verse_key,
        similarity: span[:score].to_f.round(4),
        matched_span: [span[:start].to_i + 1, span[:end].to_i + 1],
        missing_words: missing_words,
        status: status
      }
    end
  end
end
