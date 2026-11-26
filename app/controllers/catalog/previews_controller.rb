# frozen_string_literal: true

module Catalog
  # /resources/:type/:slug/preview: a published resource's card preview as JSON (Previews::Card),
  # which a resource card fetches once it is on screen. A type without a card preview, a resource
  # that cannot be shown and a wrong type are 404s. Same-origin and internal: not part of the
  # public API.
  #
  # The answer is the same for every visitor, so the URL a card fetches (with the `v` of
  # Previews::Card.version) is public and kept by shared caches (DECISIONS.md). It reads nothing
  # of the visitor and writes no cookie: no session (a card's answer arriving after the sign-in
  # page would also replace the return path), no XSRF cookie, no Warden. A URL without `v`, a
  # restricted resource and a 404 stay out of shared caches.
  class PreviewsController < ApplicationController
    MAX_AGE = 1.hour
    SHARED_MAX_AGE = 1.day

    self.allow_forgery_protection = false
    skip_before_action :set_paper_trail_whodunnit
    before_action { request.session_options[:skip] = true }
    rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

    def show
      response.headers['X-Robots-Tag'] = 'noindex'
      resource = ResourcePage.find(params[:slug])
      preview = Previews::Card.for(resource) if params[:type] == resource.resource_type
      return head :not_found unless preview

      cache(shared: params[:v].present? && !resource.restrict_download?)
      render json: preview
    end

    private

    def cache(shared:)
      if shared
        expires_in MAX_AGE, public: true, 's-maxage': SHARED_MAX_AGE.to_i, stale_while_revalidate: SHARED_MAX_AGE
      else
        expires_in MAX_AGE
      end
    end
  end
end
