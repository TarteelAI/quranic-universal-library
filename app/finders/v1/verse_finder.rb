module V1
  class VerseFinder < BaseFinder
    def verses(filter_id:, filter:, words: false, mushaf_id:, word_translation_language: nil, translations: [], range: nil)
      query = send(filter, filter_id.to_i, range)

      if words
        word_eagerload = [:mushaf_word]
        word_eagerload_filter = {
          mushaf_word: { mushaf_id: mushaf_id }
        }

        if word_translation_language
          word_eagerload << :word_translation
          word_eagerload_filter[:word_translation] = { language_id: word_translation_language }
        end

        query = query
                  .includes(words: word_eagerload)
                  .where(word_eagerload_filter)
                  .order('words.position ASC')
      end

      if translations.present?
        query = query
                  .eager_load(:translations)
                  .where(translations: { resource_content_id: translations })
      end

      query
    end

    protected
    def by_chapter(chapter, ayah_range = nil)
      from, to = Utils::Quran.get_surah_ayah_range(chapter.to_i)

      if ayah_range
        from = [from, Utils::Quran.get_ayah_id(chapter.to_i, ayah_range[0])].max
        to = [to, Utils::Quran.get_ayah_id(chapter.to_i, ayah_range[1])].min
      end

      range_from, range_to = get_ayah_range_to_load(from, to)

      Verse
        .order('verse_index ASC')
        .where('verses.verse_index >= ? AND verses.verse_index <= ?', range_from, range_to)
    end
  end
end