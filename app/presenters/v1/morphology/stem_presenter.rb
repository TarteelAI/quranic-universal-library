module V1
  module Morphology
    class StemPresenter < ApplicationPresenter
      def stems
        finder.stems
      end

      def stem
        finder.stem(params[:id]) || raise_not_found("Stem", params[:id])
      end

      protected
      def finder
        @finder ||= ::V1::Morphology::StemFinder.new(
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
end