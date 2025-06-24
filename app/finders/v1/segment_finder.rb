module V1
  class SegmentFinder < BaseFinder
    def ayah_segments(recitation:, chapter:, ayah_range: nil)
      from, to = Utils::Quran.get_surah_ayah_range(chapter.to_i)

      if ayah_range
        from = [from, Utils::Quran.get_ayah_id(chapter.to_i, ayah_range[0])].max
        to = [to, Utils::Quran.get_ayah_id(chapter.to_i, ayah_range[1])].min
      end

      range_from, range_to = get_ayah_range_to_load(from, to)

      ::AudioFile
        .where(
          recitation_id: recitation,
          chapter_id: chapter
        )
        .order('verse_id ASC')
        .where('verse_id >= ? AND verse_id <= ?', range_from, range_to)
    end

    def surah_segments(recitation:, chapter:, ayah_range: nil)
      from, to = Utils::Quran.get_surah_ayah_range(chapter.to_i)

      if ayah_range
        from = [from, Utils::Quran.get_ayah_id(chapter.to_i, ayah_range[0])].max
        to = [to, Utils::Quran.get_ayah_id(chapter.to_i, ayah_range[1])].min
      end

      range_from, range_to = get_ayah_range_to_load(from, to)

      ::Audio::Segment
        .where(
          audio_recitation_id: recitation,
          chapter_id: chapter
        )
        .order('verse_id ASC')
        .where('verse_id >= ? AND verse_id <= ?', range_from, range_to)
    end

    protected

    def by_chapter(id)
      from, to = Utils::Quran.get_surah_ayah_range(id.to_i)
      range_from, range_to = get_ayah_range_to_load(from, to)

      Verse
        .order('verse_index ASC')
        .where('verses.verse_index >= ? AND verses.verse_index <= ?', range_from, range_to)
    end
  end
end