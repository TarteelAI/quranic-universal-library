# frozen_string_literal: true

module Dev
  # Props of the development-only Inertia sample page (Dev::InertiaSamplesController#show).
  class InertiaSamplesShowResource < ApplicationResource
    typelize heading: :string
    attributes :heading

    typelize :number
    attribute :published_resource_count, inertia: :defer do
      DownloadableResource.published.count
    end
  end
end
