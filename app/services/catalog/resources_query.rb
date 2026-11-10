# frozen_string_literal: true

module Catalog
  # Published catalog resources, with the language, replacement and links of each one. It
  # depends on no controller, request or session, so the public API can reuse it.
  #
  # Resources are CMS rows; resource contents and languages are in the Quran content database.
  # SQL cannot join the two, so they are preloaded in separate queries.
  class ResourcesQuery
    def initialize(type: nil)
      @type = type
    end

    def call
      scope = DownloadableResource.published.preload(
        :language, :superseded_by, resource_content: :language, downloadable_related_resources: :related_resource
      )
      scope = scope.where(resource_type: @type) if @type
      scope.sort_by { |resource| resource.name.downcase }
    end
  end
end
