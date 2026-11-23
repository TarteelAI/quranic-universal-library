# frozen_string_literal: true

module Account
  # The signed-in user on their own profile page. `about` is prose HTML (Content::Prose).
  class PersonResource < ApplicationResource
    typelize name: :string, initials: :string, email: :string, member_since: :string,
             about: [:string, { nullable: true }]
    attributes :name, :initials, :email, :member_since, :about
  end
end
