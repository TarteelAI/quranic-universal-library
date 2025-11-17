module V1
  module Morphology
    class RootFinder < BaseFinder
      def roots
        filters = {}
        
        if params[:word_id]
          # Find roots for a specific word
          word = Word.find(params[:word_id])
          return word.roots.includes(:words).order(:value)
        end
        
        if params[:verse_id]
          # Find all roots used in a specific verse
          verse = Verse.find(params[:verse_id])
          return Root.joins(words: :verse)
                    .where(verses: { id: verse.id })
                    .includes(:words)
                    .distinct
                    .order(:value)
        end
        
        if params[:chapter_id]
          # Find all roots used in a specific chapter
          chapter = Chapter.find(params[:chapter_id])
          return Root.joins(words: :verse)
                    .where(verses: { chapter_id: chapter.id })
                    .includes(:words)
                    .distinct
                    .order(:value)
        end

        query = Root.includes(:words).order(:value)
        
        if params[:value]
          query = query.where("value ILIKE ?", "%#{params[:value]}%")
        end

        paginate_results(query)
      end

      def root(id)
        Root.includes(:words, words: :verse).find_by(id: id)
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