module Audio
  class SplitGapelessSegment
    include Utils::StrongMemoize

    def initialize(surah_recitation_id, ayah_recitation_id)
      @recitation = Audio::Recitation.find(surah_recitation_id)
      @ayah_recitation = Recitation.find(ayah_recitation_id)
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
      gapless_segments = load_ayah_segment(verse)

      audio_file = AudioFile.where(verse: verse, recitation_id: @ayah_recitation.id).first_or_initialize
      audio_file.set_segments(gapless_segments)
      audio_file.save
    end

    def load_ayah_segment(verse)
      segment = load_segments(verse.chapter_id)[verse.verse_key]

      segment.segments.map do |s|
        [s[0], s[1]-segment.timestamp_from, s[2]-segment.timestamp_from]
      end
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