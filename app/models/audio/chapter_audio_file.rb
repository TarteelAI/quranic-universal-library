# frozen_string_literal: true
# == Schema Information
#
# Table name: audio_chapter_audio_files
#
#  id                  :bigint           not null, primary key
#  audio_url           :string
#  bit_rate            :integer
#  download_count      :integer
#  duration            :integer
#  duration_ms         :integer
#  file_name           :string
#  file_size           :float
#  format              :string
#  meta_data           :jsonb
#  mime_type           :string
#  segments_count      :integer          default(0)
#  stream_count        :integer
#  timing_percentiles  :string           is an Array
#  total_files         :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  audio_recitation_id :integer
#  chapter_id          :integer
#  resource_content_id :integer
#
# Indexes
#
#  index_audio_chapter_audio_files_on_audio_recitation_id  (audio_recitation_id)
#  index_audio_chapter_audio_files_on_chapter_id           (chapter_id)
#  index_audio_chapter_audio_files_on_format               (format)
#  index_audio_chapter_audio_files_on_resource_content_id  (resource_content_id)
#

module Audio
  class ChapterAudioFile < QuranApiRecord
    include StripWhitespaces
    include Resourceable
    include HasMetaData

    belongs_to :audio_recitation, class_name: 'Audio::Recitation'
    belongs_to :chapter
    has_many :audio_segments, class_name: 'Audio::Segment', foreign_key: 'audio_file_id'

    def one_ayah?
      false
    end

    def has_audio_meta_data?
      [duration, bit_rate, file_size, mime_type].all?(&:present?)
    end

    def audio_format
      read_attribute('format') || audio_url.split('.').last || 'mp3'
    end

    def self.with_segments_counts
      left_outer_joins(:audio_segments)
        .select('audio_chapter_audio_files.*, COUNT(audio_segments.id) AS segments_count')
        .group('audio_chapter_audio_files.id')
    end

    def has_missing_segments?
      chapter && chapter.verses_count != segments_count.to_i
    end

    def humanize
      "#{id} - Surah #{chapter_id} - #{audio_recitation.name}"
    end

    def segment_progress
      if total_segments.zero?
        0
      else
        (total_verses / total_segments.to_f) * 100
      end
    end

    def update_segment_percentile
      total_duration = duration_ms.to_i

      Verse.where(chapter: chapter).order('verse_index ASC').each do |verse|
        if segment = Audio::Segment.where(verse: verse, audio_recitation_id: audio_recitation.id).first
          percentile = (segment.duration_ms.to_f / total_duration) * 100
          segment.update_column(:percentile, percentile.round(2))
        end
      end

      percentiles = []
      0.upto(100) do |i|
        timestamp = (i.to_f / 100) * total_duration

        if (file_segments = audio_segments.order('verse_number ASC')).present?
          segment = find_closest_segment(file_segments, timestamp)
          percentiles.push segment.verse_key
        end
      end

      self.timing_percentiles = percentiles
      self.segments_count = audio_segments.count
      self.save(validate: false)
    end

    def prepare_wav_manifest!
      Audio::GenerateAudioWavManifest.new(self).run(split_audio: Rails.env.development?)
    end

    protected

    def find_closest_segment(segments, time)
      closest_segment = segments[0]
      closest_diff = (closest_segment.timestamp_median - time).abs

      segments.each do |segment|
        diff = (segment.timestamp_median - time).abs

        if closest_diff >= diff && time > closest_segment.timestamp_to
          closest_diff = diff
          closest_segment = segment
        end
      end

      closest_segment
    end

    def attributes_to_strip
      [:file_name, :audio_url, :mime_type, :format]
    end

    def total_verses
      chapter.verses_count
    end

    def total_segments
      read_attribute(:total_segments).to_f
    end

    def wav_parts
      meta_value('wav_parts') || []
    end

    def has_wav_parts?
      wav_parts.any?
    end
  end
end
