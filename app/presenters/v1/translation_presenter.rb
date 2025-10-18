module V1
  class TranslationPresenter < ApplicationPresenter
    def translations
      finder.translations
    end

    def translation
      finder.translation(params[:id]) || raise_not_found("Translation", params[:id])
    end

    protected
    def finder
      @finder ||= ::V1::TranslationFinder.new(
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