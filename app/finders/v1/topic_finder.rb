module V1
  class TopicFinder < BaseFinder
    def topics
      filters = {}
      
      if params[:verse_id]
        # Find topics associated with a specific verse
        verse = Verse.find(params[:verse_id])
        return Topic.joins(:verse_topics)
                   .where(verse_topics: { verse_id: verse.id })
                   .includes(:verse_topics, :verses)
                   .order(:name)
      end
      
      if params[:chapter_id]
        # Find topics for verses in a specific chapter
        verses = Verse.where(chapter_id: params[:chapter_id]).pluck(:id)
        return Topic.joins(:verse_topics)
                   .where(verse_topics: { verse_id: verses })
                   .includes(:verse_topics, :verses)
                   .distinct
                   .order(:name)
      end
      
      if params[:parent_id]
        filters[:parent_id] = params[:parent_id]
      end
      
      if params[:thematic] == 'true'
        filters[:thematic] = true
      elsif params[:thematic] == 'false'
        filters[:thematic] = false
      end
      
      if params[:ontology] == 'true'
        filters[:ontology] = true
      elsif params[:ontology] == 'false'
        filters[:ontology] = false
      end

      query = Topic.includes(:parent, :children, :verses).order(:name)
      
      filters.each do |key, value|
        query = query.where(key => value)
      end

      paginate_results(query)
    end

    def topic(id)
      Topic.includes(:parent, :children, :verses, :verse_topics).find_by(id: id)
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