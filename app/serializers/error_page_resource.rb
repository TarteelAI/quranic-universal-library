# frozen_string_literal: true

# Props of the error page (InertiaController#render_not_found).
class ErrorPageResource < ApplicationResource
  typelize status: :number
  attributes :status
end
