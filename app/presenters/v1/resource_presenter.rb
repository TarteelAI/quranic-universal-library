module V1
  class ResourcePresenter < ApplicationPresenter
    def resources
      finder.resources
    end

    def resource
      finder.resource(params[:id]) || raise_not_found("Resource", params[:id])
    end

    protected
    def finder
      @finder ||= ::V1::ResourceFinder.new(
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