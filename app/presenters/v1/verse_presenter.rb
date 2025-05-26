module V1
  class VersePresenter < BasePresenter
    def verses
      filters = {
        filter: params[:filter_by].to_s.strip.downcase,
        words: render_words?
      }
      if render_word_translation?
        filters[:word_translation_language] = word_translation_language
      end

      list = finder.verses(
        **filters
      )

      @pagination, list = pagy(list)

      list
    end

    def select2
      list = filter(Verse.order('verse_index ASC'))

      @pagination, list = pagy(list)

      list
    end

    def render_words?
      lookahead.selects?(:words)
    end

    def render_word_translation?
      lookahead.selects?(:word_translation)
    end

    def word_translation_language
      lang = params[:word_translation_language].presence || 'en'
      word_translations = ResourceContent.translations.one_word.approved
      language = Language
                   .where(iso_code: lang, id: word_translations.pluck(:language_id))
                   .first
      if language
        language.id
      else
        38 # english
      end
    end

    def verse_fields
      []
    end

    def word_fields
      []
    end

    protected

    def finder
      VerseFinder.new(locale: api_locale)
    end

    def filter(list)
      query = params[:query].to_s.strip

      if query.present?
        list.where("verse_key ILIKE :query", query: "%#{query}%")
      else
        list
      end
    end
  end
end