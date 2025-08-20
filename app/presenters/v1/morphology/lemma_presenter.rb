module V1
  module Morphology
    class LemmaPresenter < ApplicationPresenter
      def lemmas
        finder.lemmas
      end

      def lemma
        finder.lemma(params[:id]) || raise_not_found("Lemma", params[:id])
      end

      protected
      def finder
        @finder ||= ::V1::Morphology::LemmaFinder.new(
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