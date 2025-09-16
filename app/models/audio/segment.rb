# frozen_string_literal: true
# == Schema Information
#
# Table name: audio_segments
#
#  id                       :bigint           not null, primary key
#  duration                 :integer
#  duration_ms              :integer
#  has_repetition           :boolean          default(FALSE)
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
  class Segment < QuranApiRecord
    belongs_to :verse
    belongs_to :chapter
    belongs_to :audio_recitation, class_name: 'Audio::Recitation'
    belongs_to :audio_file, class_name: 'Audio::ChapterAudioFile'

    def word_text
      Word.order('position ASC').where(verse_id: verse.id).pluck(:text_qpc_hafs)
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
      words = verse.words_count

      list = segments_list.map do |s|
        s = s.map(&:to_i)

        if s.size == 3 && s[0] <= words
          s
        end
      end

      list = list.compact_blank
      self.segments = list
      self.segments_count = list.size
    end

    def update_time_and_offset_segments(from, to, key)
      if from.present? && to.present?
        set_timing(from, to, Verse.find_by(verse_key: key))
      end

      save(validate: false)
    end

    def get_segments
      segments.map do |s|
        next if s.size < 2

        if s.size == 4
          s.drop(1)
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
  end
end
