module V1
  class VerseFinder < BaseFinder
    def verses(filter_id:, filter:, words: false, mushaf_id:, word_translation_language: nil, translations: [])
      query = send(filter, filter_id)

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
    def by_chapter(id)
      Verse
        .joins(:chapter)
        .where(chapters: { id: id.to_i })
        .order('verse_index ASC')
    end
  end
end