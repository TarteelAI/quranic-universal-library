# frozen_string_literal: true

# Base controller for the Inertia pages in app/frontend/pages.
class InertiaController < ApplicationController
  include Alba::Inertia::Controller

  layout 'inertia'

  inertia_share { SharedPropsResource.new({ signed_in: user_signed_in? }).serializable_hash }
end
