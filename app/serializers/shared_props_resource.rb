# frozen_string_literal: true

# Props every Inertia page receives (InertiaController.inertia_share).
class SharedPropsResource < ApplicationResource
  typelize signed_in: :boolean
  attributes :signed_in
end
