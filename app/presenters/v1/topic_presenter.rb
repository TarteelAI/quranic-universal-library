module V1
  class TopicPresenter < ApplicationPresenter
    def topics
      finder.topics
    end

    def topic
      finder.topic(params[:id]) || raise_not_found("Topic", params[:id])
    end

    protected
    def finder
      @finder ||= ::V1::TopicFinder.new(
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