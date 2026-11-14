# frozen_string_literal: true
# == Schema Information
#
# Table name: audio_segments
#
#  id                       :bigint           not null, primary key
#  duration                 :integer
#  duration_ms              :integer
#  has_repetition           :boolean          default(FALSE)
#  letter_segments          :jsonb
#  percentile               :float
#  relative_segments        :jsonb
#  relative_silent_duration :integer
#  repeated_segments        :string
#  segments                 :jsonb
#  segments_count           :integer          default(0)
#  silent_duration          :integer
#  timestamp_from           :integer
#  timestamp_median         :integer
#  timestamp_to             :integer
#  verse_key                :string
#  verse_number             :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  audio_file_id            :bigint
#  audio_recitation_id      :bigint
#  chapter_id               :bigint
#  verse_id                 :bigint
#
# Indexes
#
#  index_audio_segments_on_audio_file_id                   (audio_file_id)
#  index_audio_segments_on_audio_file_id_and_verse_number  (audio_file_id,verse_number) UNIQUE
#  index_audio_segments_on_audio_recitation_id             (audio_recitation_id)
#  index_audio_segments_on_chapter_id                      (chapter_id)
#  index_audio_segments_on_has_repetition                  (has_repetition)
#  index_audio_segments_on_verse_id                        (verse_id)
#  index_audio_segments_on_verse_number                    (verse_number)
#  index_on_audio_segments_median_time                     (audio_recitation_id,chapter_id,verse_id,timestamp_median)
#

module Audio
  class Segment < QulQuranRecord
    belongs_to :verse, optional: true
    belongs_to :chapter
    belongs_to :audio_recitation, class_name: 'Audio::Recitation'
    belongs_to :audio_file, class_name: 'Audio::ChapterAudioFile'

    validate :segments_must_be_arrays
    before_save :normalize_segments
    before_save :sync_timing

    # The CMS form (and any other HTML form) submits jsonb columns as strings.
    # Parse them here so a String never gets persisted inside the jsonb column,
    # which breaks every reader that calls `segments.map`.
    def segments=(value)
      super(Audio::SegmentNormalizer.parse(value) || value)
    end

    def letter_segments=(value)
      super(Audio::SegmentNormalizer.parse(value) || value)
    end

    def word_text
      Word.order('position ASC').where(verse_id: verse.id).pluck(:text_qpc_hafs)
    end

    def transcript(script: :text_imlaei, as_array: false)
      return as_array ? [] : '' if verse.blank? || segments.blank?

      # Reuse the words if they're preloaded
      words_by_position = if verse.words.loaded?
                            verse.words.map { |word| [word.position, word[script]] }.to_h
                          else
                            verse.words.order(:position).pluck(:position, script).to_h
                          end

      words = get_segments.map { |seg| words_by_position[seg[0]] }.compact_blank
      as_array ? words : words.join(' ')
    end

    def surah_number
      chapter_id
    end

    def ayah_number
      verse_number
    end

    def duration_sec
      duration
    end

    def set_timing(from, to, verse)
      from = from.to_i
      to = to.to_i

      segment_duration = to - from

      self.timestamp_from = from
      self.timestamp_to = to
      self.duration_ms = segment_duration
      self.duration = (segment_duration.to_f / 1000).round(2)
      self.timestamp_median = (from + to) / 2
      self.verse_number = verse.verse_number
      self.verse_key = verse.verse_key
      self.chapter_id = verse.chapter_id
    end

    def set_segments!(segments_list, user = nil)
      set_segments(segments_list, user)
      save(validate: false)
    end

    def set_segments(segments_list, user = nil)
      words_count = verse.words_count

      list = segments_list.map do |s|
        word_number = s[0].to_i
        next if word_number > words_count

        start_time = s[1].to_i
        end_time = s[2].to_i
        metadata = s[3] || {}

        if metadata.present? && metadata['waqaf']
          [word_number, start_time, end_time, {waqaf: true}]
        else
          [word_number, start_time, end_time]
        end
      end

      # The builder pads incomplete repeats with placeholder words that have
      # no timing (start == end == 0). Those are UI-only; never persist them.
      list = Audio::SegmentNormalizer.clean(list.compact_blank)
      self.segments = list
      self.segments_count = list.size
    end

    def set_letter_segments!(letter_list, user = nil)
      set_letter_segments(letter_list, user)
      save(validate: false)
    end

    def set_letter_segments(letter_list, user = nil)
      words_count = verse.words_count

      list = (letter_list || []).map do |l|
        word_number = l[0].to_i
        next if word_number > words_count

        [word_number, l[1].to_s, l[2].to_i, l[3].to_i]
      end.compact_blank

      self.letter_segments = list
    end

    def get_letter_segments
      return [] if letter_segments.blank?

      letter_segments.map do |l|
        next if l.size < 4

        l
      end.compact_blank
    end

    def update_time_and_offset_segments(from, to, key)
      if from.present? && to.present?
        set_timing(from, to, Verse.find_by(verse_key: key))
      end

      save(validate: false)
    end

    # Marks a return to an earlier ayah inside repeated_segments, next to the
    # within-ayah ranges: [[9, 15], {"cross_ayah": [71, 72]}].
    CROSS_AYAH_KEY = 'cross_ayah'

    scope :has_cross_ayah_repeat, lambda { |value = true|
      marked = where(has_repetition: true).where('repeated_segments LIKE ?', "%\"#{CROSS_AYAH_KEY}\"%")
      ActiveModel::Type::Boolean.new.cast(value) ? marked : where.not(id: marked.select(:id))
    }

    def self.ransackable_scopes(*)
      %i[has_cross_ayah_repeat]
    end

    def cross_ayah_repeats
      rows = Audio::Segment.where(audio_recitation_id: audio_recitation_id, chapter_id: chapter_id)
                           .pluck(:verse_number, :segments)
      self.class.cross_ayah_repeats_in(rows)[verse_number] || []
    end

    def self.cross_ayah_repeats_in(rows)
      words = rows.to_h do |vn, segs|
        list = (Audio::SegmentNormalizer.parse(segs) || segs)
        list = Array(list).select { |w| w.is_a?(Array) && w.size >= 3 && w[1].is_a?(Numeric) && w[2].is_a?(Numeric) }
        [vn, list.map { |w| [w[0].to_i, w[1].to_f, w[2].to_f] }]
      end
      # Every real word of the surah by start time, to find what lies in a gap.
      timeline = words.flat_map { |vn, list| list.select { |w| w[2] > w[1] }.map { |w| [w[1], w[2], vn] } }.sort
      starts = timeline.map(&:first)

      words.each_with_object({}) do |(vn, list), found|
        list.each_cons(2) do |a, b|
          next unless b[1] > a[2]

          from = starts.bsearch_index { |t| t >= a[2] } || starts.size
          ayahs = []
          while from < starts.size && starts[from] < b[1]
            start, finish, other = timeline[from]
            ayahs << other if other != vn && start >= a[2] && finish <= b[1]
            from += 1
          end
          next if ayahs.empty?

          (found[vn] ||= []) << { after_word: a[0], back_to_word: b[0], gap_from: a[2].to_i, gap_to: b[1].to_i,
                                  ayahs: ayahs.uniq.sort }
        end
      end
    end

    def self.track_repetition!(recitation_id, chapter_id: nil)
      scope = where(audio_recitation_id: recitation_id)
      scope = scope.where(chapter_id: chapter_id) if chapter_id
      changed = 0

      scope.select(:id, :chapter_id, :verse_number, :segments, :has_repetition, :repeated_segments)
           .group_by(&:chapter_id).each_value do |segments|
        cross = cross_ayah_repeats_in(segments.map { |s| [s.verse_number, s.segments] })
        segments.each do |segment|
          within = segment.find_repeated_segments
          returns = cross[segment.verse_number]
          stored =
            if returns
              (within + [{ CROSS_AYAH_KEY => returns.flat_map { |r| r[:ayahs] }.uniq.sort }]).to_json
            else
              within.to_s
            end
          flag = within.present? || returns.present?
          next if segment.has_repetition == flag && segment.repeated_segments == stored

          segment.update_columns(has_repetition: flag, repeated_segments: stored)
          changed += 1
        end
      end
      changed
    end

    def get_segments(drop_metadata: false)
      return [] if segments.blank?

      # Tolerate rows that were corrupted with a JSON string instead of an array
      list = Audio::SegmentNormalizer.parse(segments) || []

      list.map do |s|
        next if !s.is_a?(Array) || s.size < 2

        if drop_metadata
          [s[0], s[1], s[2]]
        else
          s
        end
      end.compact_blank
    end

    def find_repeated_segments
      segment_list = get_segments.map do |s|
        s[0]
      end

      ranges = []
      seen = {}

      segment_list.each_with_index do |num, i|
        prev_index = seen[num]

        if prev_index
          length = i - prev_index
          if segment_list[prev_index, length] == segment_list[i, length]
            ranges << [segment_list[i], segment_list[i + length - 1]]
          end
        end

        seen[num] = i
      end

      ranges.uniq
    end

    private

    def segments_must_be_arrays
      errors.add(:segments, 'must be a JSON array of [word, from, to] entries') unless segments.nil? || segments.is_a?(Array)
      errors.add(:letter_segments, 'must be a JSON array') unless letter_segments.nil? || letter_segments.is_a?(Array)
    end

    # Keep the derived duration columns in step when from/to are edited directly
    # (e.g. in the CMS) instead of through set_timing.
    def sync_timing
      return unless will_save_change_to_timestamp_from? || will_save_change_to_timestamp_to?
      return if timestamp_from.nil? || timestamp_to.nil?

      self.duration_ms = timestamp_to - timestamp_from
      self.duration = (duration_ms.to_f / 1000).round(2)
      self.timestamp_median = (timestamp_from + timestamp_to) / 2
    end

    # Runs for every save path (builder, CMS, importers, save(validate: false)).
    def normalize_segments
      return unless segments.is_a?(Array)

      cleaned = Audio::SegmentNormalizer.clean(segments)
      self.segments = cleaned if cleaned != segments
      self.segments_count = cleaned.size
    end
  end
end
