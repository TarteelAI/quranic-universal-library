# frozen_string_literal: true

module Utils
  class MergeAyahSegment
    attr_reader :ayah_recitation, :surah_recitation

    def initialize(recitation_id)
      @ayah_recitation = Recitation.find(recitation_id)
      @surah_recitation = Audio::Recitation.find(recitation_id)
    end

    def merge(chapter_id = nil)
      if chapter_id
        chapter = Chapter.find(chapter_id)
        merge_segment_for_chapter(chapter)
        update_percentiles_for_chapter(chapter)
      else
        Chapter.order('id ASC').each do |chapter|
          merge_segment_for_chapter(chapter)
          update_percentiles_for_chapter(chapter)
        end
      end
    end

    protected

    def merge_segment_for_chapter(chapter)
      surah_audio_file = Audio::ChapterAudioFile.where(chapter_id: chapter.id, audio_recitation: surah_recitation).first
      timing_file = CSV.read("data/raw_segments/#{surah_recitation.id}/timing/#{chapter.id}.csv")
      Verse.where(chapter: chapter).order('verse_number ASC').each do |verse|
        verse_timing = timing_file[verse.verse_number]
        merge_verse_segment(verse, surah_audio_file, verse_timing)
      end
    end

    def update_percentiles_for_chapter(chapter)
      audio_file = Audio::ChapterAudioFile.where(
        audio_recitation_id: surah_recitation,
        chapter_id: chapter.id
      ).first

      total_duration = audio_file.duration_ms.to_i

      Verse.where(chapter: chapter).order('verse_index ASC').each do |verse|
        if segment = Audio::Segment.where(verse: verse, audio_recitation_id: surah_recitation).first
          percentile = (segment.duration_ms.to_f / total_duration) * 100
          segment.update_column(:percentile, percentile.round(2))
        end
      end

      percentiles = []
      0.upto(100) do |i|
        timestamp = (i.to_f / 100) * total_duration
        file_segments = Audio::Segment.where(chapter_id: chapter.id,
                                             audio_recitation_id: surah_recitation).order('verse_number ASC')
        segment = find_closest_segment(file_segments, timestamp)

        percentiles.push segment.verse_key
      end

      audio_file.timing_percentiles = percentiles
      audio_file.save(validate: false)
    end

    def merge_verse_segment(verse, surah_audio_file, timing)
      audio = verse.audio_files.where(recitation_id: ayah_recitation.id).first
      seg_offset = timing[1].to_f
      relative_segments = []
      negative_offset = 0#9.204545454545455 * verse.verse_number

      segments = (audio.segments || []).map do |s|
        relative_segments.push([s[0].to_i + 1, s[2].to_i, s[3].to_i])
        [
          s[0].to_i + 1,
          [s[2].to_i + seg_offset - negative_offset, 0].max.round,
          [s[3].to_i + seg_offset - negative_offset, 0].max.round
        ]
      end

      segment = Audio::Segment.where(
        verse_id: verse.id,
        chapter_id: verse.chapter_id,
        audio_file_id: surah_audio_file.id,
        audio_recitation_id: surah_recitation.id
      ).first_or_initialize

      segment.timestamp_from = [timing[1].to_f - negative_offset, 0].max
      segment.timestamp_to = [timing[2].to_f - negative_offset, 0].max
      segment.duration = timing[6].to_f
      segment.duration_ms = timing[3].to_f
      segment.timestamp_median = (segment.timestamp_from + segment.timestamp_to) / 2

      segment.verse_number = verse.verse_number
      segment.verse_key = verse.verse_key
      segment.segments = segments
      segment.relative_segments = relative_segments

      segment.save(validate: false)
    end

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
  end
end
