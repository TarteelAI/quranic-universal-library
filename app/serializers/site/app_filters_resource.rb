# frozen_string_literal: true

module Site
  # The filters the apps directory applied (AppDirectory::Filters).
  class AppFiltersResource < ApplicationResource
    typelize platform: [:string, { nullable: true, enum: AppDirectory::PLATFORMS.keys }],
             type: [:string, { nullable: true, enum: Catalog::Taxonomy.types.map(&:key) }]
    attributes :platform, :type
  end
end
