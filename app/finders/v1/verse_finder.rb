module V1
  class VerseFinder < BaseFinder
    def verse(id_or_key)
      Verse.find_by_id_or_key(id_or_key)
    end

    def verses(filters)
      scope = Verse.order('verses.id ASC')
      order_clauses = []

      if include_words?
        eager_load_words(
          scope,
          mushaf: Mushaf.where(is_default: true).first,
          word_translation_locale: 'en'
        )
        order_clauses << "words.position ASC, word_translations.priority ASC"
      end

      order_query = order_clauses.join(',').strip

      filter(scope, filters).order(Arel.sql(order_query))
    end

    def include_words?
      lookahead.selects?('words')
    end

    protected

    def filter(scope, condition)
      scope.where(condition)
    end

    def eager_load_words(scope, mushaf:, word_translation_locale:)
      language = Language.find_with_id_or_iso_code(word_translation_locale)

      records = scope
                  .includes(
                    words: [:word_translation, :mushaf_word]
                  ).where(mushaf_words: { mushaf_id: mushaf.id })

      words_with_default_translation = records.where(
        words: {word_translations: { language_id: Language.default.id }}
      )

      if language.nil? || language.english?
        words_with_default_translation
      else
        records
          .where(word_translations: { language_id: language.id })
          .or(words_with_default_translation)
      end
    end
  end
end