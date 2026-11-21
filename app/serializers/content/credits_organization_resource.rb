# frozen_string_literal: true

module Content
  # A published Contributor on the credits page. The description is editor HTML reduced to prose
  # (Content::Prose).
  class CreditsOrganizationResource < ApplicationResource
    typelize name: :string, url: [:string, { nullable: true }], description: :string,
             logo_url: [:string, { nullable: true }]
    attributes :name, :url

    attribute(:description) { |contributor| Prose.sanitize(contributor.description) }
    attribute(:logo_url) do |contributor|
      next unless contributor.logo.attached?

      Rails.application.routes.url_helpers.rails_blob_path(contributor.logo, only_path: true)
    end
  end
end
