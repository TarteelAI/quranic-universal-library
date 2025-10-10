module V1
  class TafsirPresenter < ApplicationPresenter
    def tafsirs
      finder.tafsirs
    end

    def tafsir
      finder.tafsir(params[:id]) || raise_not_found("Tafsir", params[:id])
    end

    protected
    def finder
      @finder ||= ::V1::TafsirFinder.new(
        locale: api_locale,
        current_page: current_page,
        per_page: per_page,
        context: context
      )
    end

    def raise_not_found(resource_type, id)
      raise ::Api::RecordNotFound.new("#{resource_type} with ID #{id} not found")
    end
  end
end