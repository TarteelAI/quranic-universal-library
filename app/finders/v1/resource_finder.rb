module V1
  class ResourceFinder < BaseFinder
    def resources
      filters = { approved: true } # Only show approved resources by default
      
      if params[:resource_type]
        filters[:resource_type] = params[:resource_type]
      end
      
      if params[:sub_type]
        filters[:sub_type] = params[:sub_type]
      end
      
      if params[:cardinality_type]
        filters[:cardinality_type] = params[:cardinality_type]
      end
      
      if params[:language_id]
        filters[:language_id] = params[:language_id]
      end
      
      if params[:author_id]
        filters[:author_id] = params[:author_id]
      end

      query = ResourceContent.includes(:language, :author, :data_source)
                            .order(:priority, :name)
      
      filters.each do |key, value|
        query = query.where(key => value)
      end

      # Handle text search
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        query = query.where("name ILIKE ? OR description ILIKE ?", search_term, search_term)
      end

      paginate_results(query)
    end

    def resource(id)
      ResourceContent.includes(:language, :author, :data_source)
                    .approved
                    .find_by(id: id)
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