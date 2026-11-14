# frozen_string_literal: true

# A font's family name and its files (Fonts::UrlResolver::Font), in the order a browser tries them.
class FontFilesResource < ApplicationResource
  typelize family: :string, per_page: :boolean
  attributes :family, :per_page

  many :sources, resource: FontSourceResource
end
