# frozen_string_literal: true

module Catalog
  # The licence of a resource (Catalog::ResourcePage::Licence).
  class ResourceLicenceResource < ApplicationResource
    typelize name: :string, url: [:string, { nullable: true }], summary: [:string, { nullable: true }]
    attributes :name, :url, :summary
  end
end
