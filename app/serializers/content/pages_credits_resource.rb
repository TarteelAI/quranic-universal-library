# frozen_string_literal: true

module Content
  # Props of the credits page (Content::PagesController#credits).
  class PagesCreditsResource < ApplicationResource
    many :organizations, resource: CreditsOrganizationResource
    many :acknowledgements, resource: CreditsAcknowledgementResource
    many :code_contributors, resource: CreditsCodeContributorResource
  end
end
