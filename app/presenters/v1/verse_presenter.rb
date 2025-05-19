module V1
  class VersePresenter < BasePresenter
    def verses
      list = filter(Verse.order('verse_index ASC'))

      @pagination, list = pagy(list)

      list
    end

    protected
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