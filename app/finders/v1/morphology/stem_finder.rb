module V1
  module Morphology
    class StemFinder < BaseFinder
      def stems
        filters = {}
        
        if params[:word_id]
          # Find stems for a specific word
          word = Word.find(params[:word_id])
          return word.stems.includes(:words).order(:text_clean)
        end
        
        if params[:verse_id]
          # Find all stems used in a specific verse
          verse = Verse.find(params[:verse_id])
          return Stem.joins(words: :verse)
                    .where(verses: { id: verse.id })
                    .includes(:words)
                    .distinct
                    .order(:text_clean)
        end
        
        if params[:chapter_id]
          # Find all stems used in a specific chapter
          chapter = Chapter.find(params[:chapter_id])
          return Stem.joins(words: :verse)
                    .where(verses: { chapter_id: chapter.id })
                    .includes(:words)
                    .distinct
                    .order(:text_clean)
        end

        query = Stem.includes(:words).order(:text_clean)
        
        if params[:text]
          query = query.where("text_clean ILIKE ?", "%#{params[:text]}%")
        end

        paginate_results(query)
      end

      def stem(id)
        Stem.includes(:words, words: :verse).find_by(id: id)
      end

      protected
      def paginate_results(query)
        total_count = query.count
        
        @pagination = Pagy.new(
          count: total_count,
          page: current_page,
          items: per_page
        )
        
        query.limit(per_page).offset(@pagination.offset)
      end
    end
  end
end