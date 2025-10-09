module Audio
  class SplitGaplessSegment
    include Utils::StrongMemoize

    attr_reader :ayah_recitation, :recitation
    def initialize(surah_recitation_id, ayah_recitation_id)
      @recitation = Audio::Recitation.find(surah_recitation_id)
      @ayah_recitation = ::Recitation.find(ayah_recitation_id)
    end

    def split_surah(chapter_id)
      Verse
        .where(chapter_id: chapter_id)
        .order('verse_number ASC')
        .each do |verse|
          split_ayah(verse)
      end
    end

    def split_ayah(verse)
      gapped_segments = load_ayah_segment(verse)
      audio_file = AudioFile
                     .where(
                       verse: verse,
                       recitation_id: ayah_recitation.id
                     ).first_or_initialize

      audio_file.set_segments(gapped_segments)
      audio_file.save(validate: false)
    end

    def load_ayah_segment(verse)
      segment = load_segments(verse.chapter_id)[verse.verse_key]
      return [] if segment.blank? || segment.segments.blank?

      segment_start = [segment.timestamp_from, segment.segments[0][1]].min

      segments = segment.segments.map do |s|
        next if s[0] > verse.words_count || s.size < 3

        [
          s[0], s[1] - segment_start,
          s[2] - segment_start
        ]
      end

      segments.compact_blank
    end

    protected

    def load_segments(chapter_id)
      strong_memoize "surha_#{chapter_id}_segments" do
        segments = {}

        Audio::Segment.where(chapter_id: chapter_id, audio_recitation: @recitation).each do |segment|
          segments[segment.verse_key] = segment
        end

        segments
      end
    end
  end
end