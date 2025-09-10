module V1
  class TafsirFinder < BaseFinder
    def tafsirs
      filters = {}
      
      if params[:verse_id]
        verse_id = params[:verse_id].to_i
        # Find tafsirs that include this verse in their range
        return Tafsir.includes(:verse, :chapter, :language)
                    .where(":verse_id >= start_verse_id AND :verse_id <= end_verse_id", verse_id: verse_id)
                    .order('start_verse_id ASC, priority ASC')
      end
      
      if params[:chapter_id]
        filters[:chapter_id] = params[:chapter_id]
      end
      
      if params[:resource_content_id]
        filters[:resource_content_id] = params[:resource_content_id]
      end
      
      if params[:language_id]
        filters[:language_id] = params[:language_id]
      end

      query = Tafsir.includes(:verse, :chapter, :language)
                   .order('start_verse_id ASC, priority ASC')
      
      filters.each do |key, value|
        query = query.where(key => value)
      end

      paginate_results(query)
    end

    def tafsir(id)
      Tafsir.includes(:verse, :chapter, :language).find_by(id: id)
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