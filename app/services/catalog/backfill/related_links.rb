# frozen_string_literal: true

module Catalog
  module Backfill
    # Removes related-resource links with a missing end, then repeated pairs (the oldest row of
    # each pair stays).
    module RelatedLinks
      def self.call
        links = DownloadableRelatedResource
        resource_ids = DownloadableResource.select(:id)

        orphaned = links.where(downloadable_resource_id: nil).or(links.where(related_resource_id: nil))
                        .or(links.where.not(downloadable_resource_id: resource_ids))
                        .or(links.where.not(related_resource_id: resource_ids))
                        .delete_all
        first_of_pair = links.group(:downloadable_resource_id, :related_resource_id).select('MIN(id)')

        orphaned + links.where.not(id: first_of_pair).delete_all
      end
    end
  end
end
