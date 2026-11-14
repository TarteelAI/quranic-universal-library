# frozen_string_literal: true

module Catalog
  # /bundle?ids=1,2: what the resources of the visitor's bundle are now, as JSON, for the bundle
  # tray (Catalog::Bundle). The bundle itself is browser state; this only shows what the catalog
  # already shows. Same-origin and internal: not versioned and not part of the public API.
  class BundlesController < ApplicationController
    def show
      response.headers['X-Robots-Tag'] = 'noindex'
      render json: BundleResource.new(Bundle.new(Bundle.ids(params[:ids]), viewer: current_user)).serializable_hash
    end
  end
end
