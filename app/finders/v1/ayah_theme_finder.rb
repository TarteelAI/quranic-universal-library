module V1
  class AyahThemeFinder < BaseFinder
    def ayah_themes
      filters = {}
      
      if params[:verse_id]
        verse_id = params[:verse_id].to_i
        # Find themes that include this verse in their range
        return AyahTheme.includes(:chapter, :verse_from, :verse_to)
                       .where(":verse_id >= verse_id_from AND :verse_id <= verse_id_to", verse_id: verse_id)
                       .order('verse_id_from ASC')
      end
      
      if params[:chapter_id]
        filters[:chapter_id] = params[:chapter_id]
      end
      
      if params[:theme]
        # Allow filtering by theme text (case-insensitive partial match)
        return AyahTheme.includes(:chapter, :verse_from, :verse_to)
                       .where("theme ILIKE ?", "%#{params[:theme]}%")
                       .order('verse_id_from ASC')
      end

      query = AyahTheme.includes(:chapter, :verse_from, :verse_to)
                      .order('verse_id_from ASC')
      
      filters.each do |key, value|
        query = query.where(key => value)
      end

      paginate_results(query)
    end

    def ayah_theme(id)
      AyahTheme.includes(:chapter, :verse_from, :verse_to).find_by(id: id)
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