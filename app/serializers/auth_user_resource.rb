# frozen_string_literal: true

# The signed-in user in the site header (AuthResource).
class AuthUserResource < ApplicationResource
  typelize initials: :string, name: :string
  attributes :initials, :name
end
