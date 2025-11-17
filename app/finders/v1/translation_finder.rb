module V1
  class TranslationFinder < BaseFinder
    def translations
      filters = {}
      
      if params[:verse_id]
        filters[:verse_id] = params[:verse_id]
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

      query = Translation.includes(:verse, :language)
                        .order('verse_index ASC, priority ASC')
      
      filters.each do |key, value|
        query = query.where(key => value)
      end

      paginate_results(query)
    end

    def translation(id)
      Translation.includes(:verse, :language).find_by(id: id)
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