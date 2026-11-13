# frozen_string_literal: true

module Catalog
  # /resources/:type/:slug/preview: a published resource's card preview as JSON (Previews::Card),
  # which a resource card fetches once it is on screen. A type without a card preview, a resource
  # that cannot be shown and a wrong type are 404s. Same-origin and internal: not versioned and
  # not part of the public API.
  class PreviewsController < ApplicationController
    MAX_AGE = 1.hour

    rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

    def show
      response.headers['X-Robots-Tag'] = 'noindex'
      resource = ResourcePage.find(params[:slug])
      preview = Previews::Card.for(resource) if params[:type] == resource.resource_type
      return head :not_found unless preview

      expires_in MAX_AGE
      render json: preview
    end
  end
end
