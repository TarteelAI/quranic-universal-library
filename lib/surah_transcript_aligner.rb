class SurahTranscriptAligner
  MUSHAF_TRANSLATOR_INDEX = JSON.parse(File.read("lib/data/mushaf-translator-index.json"))

  DEFAULT_WINDOW_SIZE = 10
  SCORE_TOKEN_WEIGHT = 0.7
  SCORE_CHAR_WEIGHT = 0.3

  ARABIC_DIACRITICS_RE = /[\u064B-\u065F\u0670\u06D6-\u06ED\u08D4-\u08FF]/.freeze
  WHITESPACE_RE = /\s+/.freeze
  WAQF_RE = /[ٰۛۖۗۘۙۚۜ۞۩ۭ]/.freeze
  ARABIC_LETTER_RE = /[\u0621-\u064A]/.freeze

  CHAR_REPLACEMENT_MAP = {
    "أ" => "ا",
    "إ" => "ا",
    "آ" => "ا",
    "ٱ" => "ا",
    "ى" => "ي",
    "ؤ" => "و",
    "ئ" => "ي",
    "ة" => "ه",
    "ۥ" => "",
    "ۦ" => "",
    "ـ" => "",
    "ٰ" => "",
    "ۡ" => "",
    "ۢ" => "",
  }.freeze

  LAM_ALEF_LIGATURES = {
    "ﻻ" => "لا",
    "ﻷ" => "لا",
    "ﻹ" => "لا",
    "ﻵ" => "لا"
  }.freeze

  WORD_TEXT_MAPPING = {
    '2:181:3': {
      simple: 'بعدما',
      text: 'بَعْدَمَا'
    },
    '2:181:4': {
      simple: '',
      text: ''
    },
    '8:6:4': {
      simple: 'بعدما',
      text: 'بَعْدَمَا'
    },
    '8:6:5': {
      simple: '',
      text: ''
    },
    '13:37:8': {
      simple: 'بعدما',
      text: 'بَعْدَمَا'
    },
    '13:37:9': {
      simple: '',
      text: ''
    }
  }

  STT_PATH = "data/stt"
  OUTPUT_DIR = "#{STT_PATH}/results"

  def initialize(surah_number:, recitation_id:)
    @surah_number = surah_number.to_i
    @recitation_id = recitation_id.to_i
    @transcript_text = File.read("#{STT_PATH}/#{@recitation_id}/#{@surah_number}.txt").to_s

    @stt_raw_tokens = tokenize(@transcript_text, strip_diacritics: false)
    @stt_norm_tokens = tokenize(@transcript_text, strip_diacritics: true)

    verses = Verse
               .where(chapter_id: @surah_number)
               .includes(:actual_words)
               .order(:verse_number)

    @verse_data = verses.map do |verse|
      words = verse.actual_words.sort_by(&:position)

      canonical_raw = words.map do |w|
        text = get_word_text(w)
        remove_waqfs(text.to_s)
      end.compact_blank

      canonical_norm = canonical_raw.map do |w|
        normalize_word(w, strip_diacritics: true)
      end

      canonical_chars = canonical_norm.join.gsub(" ", "").codepoints

      {
        verse_number: verse.verse_number,
        verse_text: verse.text_imlaei.to_s,
        canonical_raw: canonical_raw,
        canonical_norm: canonical_norm,
        canonical_chars: canonical_chars
      }
    end

    @ayah_occurrence_counter = Hash.new(0)
    @total_files_written = 0
    @repetitions_detected = 0
  end

  def export_aligned_ayahs
    return {
      total_ayah_processed: 0,
      total_files_written: 0,
      repetitions_detected: 0
    } if @stt_norm_tokens.empty? || @verse_data.empty?

    cursor = 0
    processed = 0

    @verse_data.each do |vd|
      span = find_best_matching_ayah(@stt_norm_tokens, vd[:canonical_norm], cursor, DEFAULT_WINDOW_SIZE, vd[:canonical_chars])
      s = span[:start]
      e = span[:end]
      score = span[:score]

      span_raw = (s >= 0 && e >= s) ? (@stt_raw_tokens[s..e] || []) : []
      span_norm = (s >= 0 && e >= s) ? (@stt_norm_tokens[s..e] || []) : []

      stt_words = align_words(
        vd[:canonical_raw],
        vd[:canonical_norm],
        span_raw,
        span_norm,
        vd[:verse_number]
      )
      stt_words = post_process_merge_extras(stt_words, @surah_number, vd[:verse_number])

      output_hash = build_output_hash(
        ayah_number: vd[:verse_number],
        verse_text: vd[:verse_text],
        span_raw: span_raw,
        start_index: s,
        end_index: e,
        similarity: score,
        stt_words: stt_words,
        words_count: vd[:canonical_raw].length
      )
      export_ayah_stt(vd[:verse_number], output_hash)
      processed += 1

      cursor = [cursor, e + 1].max if s >= 0 && e >= s && score > 0.0
    end

    {
      total_ayah_processed: processed,
      total_files_written: @total_files_written,
      repetitions_detected: @repetitions_detected
    }
  end

  def export_ayahs_bundle
    ayahs_path = Rails.root.join(OUTPUT_DIR, @recitation_id.to_s, @surah_number.to_s)
    bundle_path = Rails.root.join(OUTPUT_DIR, "bundle", @recitation_id.to_s)

    files = Dir.glob(ayahs_path.join("*.json").to_s)

    by_ayah = Hash.new { |h, k| h[k] = [] }

    files.sort_by { |p| sort_key_for(p) }.each do |path|
      basename = File.basename(path)
      m = /\A(?<ayah>\d+)(?:_(?<occ>\d+))?\.json\z/.match(basename)
      next unless m

      ayah_number = m[:ayah].to_i
      occurrence = m[:occ] ? m[:occ].to_i : 0

      payload = JSON.parse(File.read(path))
      payload["occurrence"] = occurrence
      by_ayah[ayah_number.to_s] << payload
    end

    out = {
      "surah" => @surah_number,
      "ayahs" => by_ayah
    }

    json = JSON.pretty_generate(out, ensure_ascii: false)

    FileUtils.mkdir_p(bundle_path)
    File.write(bundle_path.join("#{@surah_number.to_s}.json"), json)
  end

  def export_fixed_stt
    ayahs_path = Rails.root.join(OUTPUT_DIR, @recitation_id.to_s, @surah_number.to_s)
    fixed_stt_path = Rails.root.join(OUTPUT_DIR, "fixed", @recitation_id.to_s)

    files = Dir.glob(ayahs_path.join("*.json").to_s)

    data = []

    files.sort_by { |p| sort_key_for(p) }.each do |path|
      basename = File.basename(path)
      m = /\A(?<ayah>\d+)(?:_(?<occ>\d+))?\.json\z/.match(basename)
      next unless m

      ayah_stt = JSON.parse(File.read(path))
      words = ayah_stt['words']
      data << words.map { |w| w['text'].to_s }.join(" ")
    end

    FileUtils.mkdir_p(fixed_stt_path)
    File.write(fixed_stt_path.join("#{@surah_number.to_s}.txt"), data.join(' '))
  end

  private

  def sort_key_for(path)
    basename = File.basename(path)
    m = /\A(?<ayah>\d+)(?:_(?<occ>\d+))?\.json\z/.match(basename)
    return [Float::INFINITY, Float::INFINITY, basename] unless m
    ayah_number = m[:ayah].to_i
    occurrence = m[:occ] ? m[:occ].to_i : 0
    [ayah_number, occurrence, basename]
  end

  def translate_imlaei_word_to_uthmani(surah, ayah, one_based_stt_index)
    surah_mapping = MUSHAF_TRANSLATOR_INDEX[surah.to_s]
    return (one_based_stt_index - 1) unless surah_mapping && surah_mapping[ayah.to_s]
    mapping = surah_mapping[ayah.to_s]
    key = one_based_stt_index.to_s
    val = mapping[key]
    if val
      val.to_i
    else
      next_val = mapping[(one_based_stt_index + 1).to_s]
      next_val ? next_val.to_i : (one_based_stt_index - 1)
    end
  end

  def post_process_merge_extras(words, surah, ayah)
    return words if words.empty?
    result = []
    previous_word = nil

    words.each_with_index do |w, index|
      merged = false
      if w["status"] == "extra" && previous_word
        if translate_imlaei_word_to_uthmani(surah, ayah, index + 1) == index
          # merge with previous and remove the "extra" status
          previous_word['stt_text'] = "#{previous_word['stt_text']} #{w['stt_text']}".strip
          previous_word['stt_text_simple'] = "#{previous_word['stt_text_simple']} #{w['stt_text_simple']}".strip
          merged = true

          if compute_similarity(w['text_simple'].chars, w['stt_text_simple'].chars) > 0.9
            # Use stt text for fixed version
            previous_word['text'] = previous_word['stt_text']
            previous_word['status'] = 'ok'
          end

          result[-1] = previous_word
        end
      end

      if !merged
        result << w
      end

      previous_word = w
    end

    result
  end

  def tokenize(text, strip_diacritics: true)
    t = normalize_arabic(text.to_s, strip_diacritics: strip_diacritics)
    t.split(" ").select { |x| x.match?(ARABIC_LETTER_RE) }
  end

  def find_best_matching_ayah(stt_tokens_norm, canonical_tokens_norm, cursor, window_size, canonical_chars)
    stt_len = stt_tokens_norm.length
    expected_len = [canonical_tokens_norm.length, 1].max

    best = nil
    best_score = 0.0

    s_min = [0, cursor - window_size].max
    s_max = [stt_len, cursor + window_size].min

    len_min = [1, expected_len - window_size].max
    len_max = expected_len + window_size

    (s_min...s_max).each do |s|
      (len_min..len_max).each do |n|
        e = s + n - 1
        next if e >= stt_len

        span_tokens_norm = stt_tokens_norm[s..e]

        token_ratio = compute_similarity(canonical_tokens_norm, span_tokens_norm)
        optimistic = (SCORE_TOKEN_WEIGHT * token_ratio) + SCORE_CHAR_WEIGHT
        next if best && optimistic < (best_score - 1e-9)

        span_chars = span_tokens_norm.join.gsub(" ", "").codepoints
        char_ratio = SequenceMatcher.new(a: canonical_chars, b: span_chars).ratio
        score = (SCORE_TOKEN_WEIGHT * token_ratio) + (SCORE_CHAR_WEIGHT * char_ratio)

        key = [score, -((n - expected_len).abs), -((s - cursor).abs)]

        if best.nil? || ((key <=> best[:key]) == 1)
          best = { start: s, end: e, score: score, key: key }
          best_score = score
        end
      end
    end

    return { start: -1, end: -1, score: 0.0 } if best.nil?

    { start: best[:start], end: best[:end], score: best[:score] }
  end

  def compute_similarity(canonical_tokens_norm, span_tokens_norm)
    SequenceMatcher.new(a: canonical_tokens_norm, b: span_tokens_norm).ratio
  end

  def align_words(canonical_raw, canonical_norm, span_raw, span_norm, ayah_number)
    sm = SequenceMatcher.new(a: canonical_norm, b: span_norm)
    opcodes = sm.get_opcodes

    out = []
    last_canonical_index = 0

    opcodes.each do |tag, i1, i2, j1, j2|
      if tag == "equal"
        (0...[i2 - i1, j2 - j1].min).each do |k|
          i = i1 + k
          j = j1 + k
          out << {
            "position" => i + 1,
            "text" => canonical_raw[i].to_s,
            "text_simple" => canonical_norm[i].to_s,
            "stt_text" => span_raw[j].to_s,
            "stt_text_simple" => span_norm[j].to_s
          }
          last_canonical_index = i + 1
        end
      elsif tag == "replace"
        a_len = i2 - i1
        b_len = j2 - j1
        common = [a_len, b_len].min

        common.times do |k|
          i = i1 + k
          j = j1 + k
          out << {
            "position" => i + 1,
            "text" => canonical_raw[i].to_s,
            "text_simple" => canonical_norm[i].to_s,
            "stt_text" => span_raw[j].to_s,
            "stt_text_simple" => span_norm[j].to_s,
            "status" => "wrong",
            "fixed" => canonical_raw[i].to_s
          }
          last_canonical_index = i + 1
        end

        (common...b_len).each do |k|
          j = j1 + k
          out << {
            "text" => span_raw[j].to_s,
            "text_simple" => span_norm[j].to_s,
            "stt_text" => span_raw[j].to_s,
            "stt_text_simple" => span_norm[j].to_s,
            "position" => nil,
            "status" => "extra"
          }
        end
      elsif tag == "delete"
        (i1...i2).each do |i|
          out << {
            "position" => i + 1,
            "text" => canonical_raw[i].to_s,
            "text_simple" => canonical_norm[i].to_s,
            "stt_text" => nil,
            "stt_text_simple" => nil,
            "status" => "missed"
          }
          last_canonical_index = i + 1
        end
      elsif tag == "insert"
        inserted_norm = span_norm[j1...j2] || []
        inserted_raw = span_raw[j1...j2] || []

        start_pos = find_contextual_repeat(canonical_norm, inserted_norm, last_canonical_index)

        inserted_raw.each_with_index do |tok, k|
          entry = {
            "text" => tok.to_s,
            "text_simple" => inserted_norm[k].to_s,
            "stt_text" => tok.to_s,
            "stt_text_simple" => inserted_norm[k].to_s
          }

          if start_pos
            entry["position"] = start_pos + k + 1
            entry["status"] = "repeat"
          else
            entry["position"] = nil
            entry["status"] = "extra"
          end

          out << entry
        end
      end
    end

    out
  end

  def export_ayah_stt(ayah_number, output_hash)
    dir = Rails.root.join(OUTPUT_DIR, @recitation_id.to_s, @surah_number.to_s)
    FileUtils.mkdir_p(dir)

    occurrence = @ayah_occurrence_counter[ayah_number]
    filename = occurrence.zero? ? "#{ayah_number}.json" : "#{ayah_number}_#{occurrence}.json"
    @repetitions_detected += 1 if occurrence.positive?
    @ayah_occurrence_counter[ayah_number] += 1

    path = dir.join(filename)
    File.write(path, JSON.pretty_generate(output_hash, ensure_ascii: false))
    @total_files_written += 1
  end

  def build_output_hash(ayah_number:, verse_text:, span_raw:, start_index:, end_index:, similarity:, stt_words:, words_count:)
    sim = similarity.to_f
    sim_rounded = ((sim * 10_000.0).round / 10_000.0)

    status =
      if sim >= 0.90
        "ok"
      elsif sim >= 0.80
        "needs_review"
      else
        "ambiguous"
      end

    counts = word_counts(stt_words)
    exact = counts["exact"].to_i
    canonical = words_count.to_i
    match_percent = canonical <= 0 ? 0.0 : ((exact.to_f / canonical) * 100.0)
    match_percent_rounded = ((match_percent * 100.0).round / 100.0)

    has_repeat = counts["repeat"].to_i > 0
    has_missing = counts["missed"].to_i > 0
    has_wrong = counts["wrong"].to_i > 0
    has_extra = counts["extra"].to_i > 0

    exact_match = (sim >= 0.9999) && !has_repeat && !has_missing && !has_wrong && !has_extra

    payload = {
      "ayah" => "#{@surah_number}:#{ayah_number}",
      "text" => verse_text.to_s,
      "stt" => span_raw.join(" "),
      "matched_stt_span" => {
        "start_token_index" => start_index.to_i >= 0 ? (start_index.to_i + 1) : -1,
        "end_token_index" => end_index.to_i >= 0 ? (end_index.to_i + 1) : -1
      },
      "similarity" => sim_rounded,
      "status" => status,
      "meta" => {
        "words_count" => canonical,
        "exact_match_percent" => match_percent_rounded,
        "exact_match" => exact_match,
        "has_repeat" => has_repeat,
        "has_missing" => has_missing,
        "has_wrong" => has_wrong,
        "has_extra" => has_extra,
        "counts" => counts
      },
      "words" => stt_words
    }

    payload
  end

  def normalize_word(text, strip_diacritics:)
    normalize_arabic(text.to_s, strip_diacritics: strip_diacritics)
    # s.split(" ").select { |x| x.match?(ARABIC_LETTER_RE) }.join(" ")
  end

  def remove_waqfs(text)
    text.to_s.gsub(/[ٰ ۖ ۗ ۘ ۙ]/, "")
  end

  def normalize_arabic(text, strip_diacritics:)
    t = (text || "").to_s
    t = t.unicode_normalize(:nfc)

    t = t.gsub(/[#{Regexp.escape(CHAR_REPLACEMENT_MAP.keys.join)}]/) { |ch| CHAR_REPLACEMENT_MAP.fetch(ch) }
    t = t.gsub(/[#{Regexp.escape(LAM_ALEF_LIGATURES.keys.join)}]/) { |ch| LAM_ALEF_LIGATURES.fetch(ch) }

    t = t.gsub(WAQF_RE, "")
    t = t.gsub(ARABIC_DIACRITICS_RE, "") if strip_diacritics
    t.gsub(WHITESPACE_RE, " ").strip
  end

  def find_contextual_repeat(canonical_norm, inserted_norm, last_canonical_index)
    n = inserted_norm.length
    return nil if n == 0

    candidates = []
    limit = canonical_norm.length - n
    return nil if limit < 0

    i = 0
    while i <= limit
      if canonical_norm[i, n] == inserted_norm
        candidates << i
      end
      i += 1
    end

    return nil if candidates.empty?

    forward = candidates.select { |c| c >= last_canonical_index }
    return forward.min if forward.any?

    candidates.min_by { |c| (c - last_canonical_index).abs }
  end

  def word_counts(stt_words)
    counts = {
      "exact" => 0,
      "wrong" => 0,
      "missed" => 0,
      "repeat" => 0,
      "extra" => 0
    }

    stt_words.each do |w|
      status = w["status"].to_s
      if status.empty?
        counts["exact"] += 1
      else
        counts[status] = counts.fetch(status, 0) + 1
      end
    end

    counts
  end

  def get_word_text(word)
    if(text = WORD_TEXT_MAPPING[word.location.to_sym])
      text[:text]
    else
      word.text_imlaei
    end
  end

  class SequenceMatcher
    def initialize(a:, b:)
      @a = a || []
      @b = b || []
      @b2j = nil
      @matching_blocks = nil
    end

    def ratio
      a_len = @a.length
      b_len = @b.length
      return 1.0 if a_len == 0 && b_len == 0
      matches = matching_blocks.sum { |blk| blk[2] }
      (2.0 * matches) / (a_len + b_len)
    end

    def get_opcodes
      ai = 0
      bi = 0
      out = []

      matching_blocks_with_sentinel.each do |a0, b0, size|
        tag = nil
        if ai < a0 && bi < b0
          tag = "replace"
        elsif ai < a0
          tag = "delete"
        elsif bi < b0
          tag = "insert"
        end

        out << [tag, ai, a0, bi, b0] if tag
        out << ["equal", a0, a0 + size, b0, b0 + size] if size.positive?

        ai = a0 + size
        bi = b0 + size
      end

      out
    end

    private

    def matching_blocks
      @matching_blocks ||= begin
                             blocks = []
                             get_matching_blocks(0, @a.length, 0, @b.length, blocks)
                             blocks.sort_by! { |x| [x[0], x[1]] }

                             merged = []
                             blocks.each do |i, j, k|
                               if merged.empty?
                                 merged << [i, j, k]
                               else
                                 pi, pj, pk = merged[-1]
                                 if pi + pk == i && pj + pk == j
                                   merged[-1] = [pi, pj, pk + k]
                                 else
                                   merged << [i, j, k]
                                 end
                               end
                             end

                             merged
                           end
    end

    def matching_blocks_with_sentinel
      mb = matching_blocks.dup
      mb << [@a.length, @b.length, 0]
      mb
    end

    def get_matching_blocks(a_lo, a_hi, b_lo, b_hi, blocks)
      i, j, k = find_longest_match(a_lo, a_hi, b_lo, b_hi)
      return if k.zero?

      get_matching_blocks(a_lo, i, b_lo, j, blocks) if a_lo < i && b_lo < j
      blocks << [i, j, k]
      get_matching_blocks(i + k, a_hi, j + k, b_hi, blocks) if (i + k) < a_hi && (j + k) < b_hi
    end

    def build_b2j
      return @b2j if @b2j
      h = Hash.new { |hh, kk| hh[kk] = [] }
      @b.each_with_index { |elt, idx| h[elt] << idx }
      @b2j = h
    end

    def find_longest_match(a_lo, a_hi, b_lo, b_hi)
      build_b2j
      best_i = a_lo
      best_j = b_lo
      best_size = 0

      j2len = {}

      (a_lo...a_hi).each do |i|
        newj2len = {}
        indices = @b2j[@a[i]]
        indices.each do |j|
          next if j < b_lo
          break if j >= b_hi
          k = (j2len[j - 1] || 0) + 1
          newj2len[j] = k
          if k > best_size
            best_i = i - k + 1
            best_j = j - k + 1
            best_size = k
          end
        end
        j2len = newj2len
      end

      [best_i, best_j, best_size]
    end
  end
end
