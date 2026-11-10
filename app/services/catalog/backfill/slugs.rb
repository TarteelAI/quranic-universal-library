# frozen_string_literal: true

module Catalog
  module Backfill
    # A slug for every resource that has none, from its display name. Existing slugs are kept.
    module Slugs
      def self.call
        taken = DownloadableResource.where.not(slug: nil).pluck(:slug).to_set

        DownloadableResource.where(slug: nil).order(:id).each do |resource|
          slug = Catalog::Slugs.generate(resource) { |candidate| taken.include?(candidate) }
          resource.update_columns(slug: slug)
          taken << slug
        end.size
      end
    end
  end
end
