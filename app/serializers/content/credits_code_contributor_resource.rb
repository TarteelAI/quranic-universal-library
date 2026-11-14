# frozen_string_literal: true

module Content
  # A code contributor of the GitHub repository (GithubService.fetch_contributors).
  class CreditsCodeContributorResource < ApplicationResource
    typelize login: :string, url: :string, avatar_url: :string, contributions: :number
    attributes :login, :contributions

    attribute(:url) { |contributor| contributor[:html_url] }
    attribute(:avatar_url) { |contributor| contributor[:avatar_url] }
  end
end
