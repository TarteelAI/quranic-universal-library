# frozen_string_literal: true

module Account
  # Props of the account settings page (Account::ProfilesController#edit), from
  # Account::Profile.settings: the values the two forms start from and the state of the email.
  class ProfilesEditResource < ApplicationResource
    typelize first_name: :string, last_name: :string, about: :string, email: :string, member_since: :string,
             email_status: [:string, { enum: Profile::EMAIL_STATUSES }],
             unconfirmed_email: [:string, { nullable: true }]
    attributes :first_name, :last_name, :about, :email, :member_since, :email_status, :unconfirmed_email
  end
end
