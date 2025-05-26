module V1
  class VerseFinder < BaseFinder
    def verses(filter:, words: false, word_translation_language: nil)
      query = Verse
                .joins(:chapter)
                .where(chapters: { id: 1 })
                .order(:verse_index)

      if words
        query = query.includes(:words)
      end

      if word_translation_language
        query = query.includes(words: :translations)
                     .where(words: { translations: { language_id: word_translation_language } })
      end

      query
    end
  end
end