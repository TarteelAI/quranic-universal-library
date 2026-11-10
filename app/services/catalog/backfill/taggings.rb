# frozen_string_literal: true

module Catalog
  module Backfill
    # Removes taggings whose resource or tag no longer exists.
    module Taggings
      def self.call
        taggings = DownloadableResourceTagging

        taggings.where.not(downloadable_resource_id: DownloadableResource.select(:id))
                .or(taggings.where.not(downloadable_resource_tag_id: DownloadableResourceTag.select(:id)))
                .delete_all
      end
    end
  end
end
