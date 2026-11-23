# frozen_string_literal: true

# The signed-in state the site header shows: the user's initials and name, or null when signed
# out. Nothing else about the account goes to the browser.
class AuthResource < ApplicationResource
  typelize user: { nullable: true }
  one :user, resource: AuthUserResource
end
