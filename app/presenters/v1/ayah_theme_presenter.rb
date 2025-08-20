module V1
  class AyahThemePresenter < ApplicationPresenter
    def ayah_themes
      finder.ayah_themes
    end

    def ayah_theme
      finder.ayah_theme(params[:id]) || raise_not_found("AyahTheme", params[:id])
    end

    protected
    def finder
      @finder ||= ::V1::AyahThemeFinder.new(
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