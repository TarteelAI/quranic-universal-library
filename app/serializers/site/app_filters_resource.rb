# frozen_string_literal: true

module Site
  # The filters the apps directory applied (AppDirectory::Filters).
  class AppFiltersResource < ApplicationResource
    typelize project_type: [:string, { nullable: true, enum: AppDirectory::PROJECT_TYPES.keys }],
             platform: [:string, { nullable: true, enum: AppDirectory::PLATFORMS.keys }],
             type: [:string, { nullable: true, enum: Catalog::Taxonomy.types.map(&:key) }]
    attributes :project_type, :platform, :type
  end
end
