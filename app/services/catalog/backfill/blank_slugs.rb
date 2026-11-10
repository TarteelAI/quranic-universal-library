# frozen_string_literal: true

module Catalog
  module Backfill
    # A blank slug is no slug: it becomes NULL so the Slugs step gives the resource one.
    module BlankSlugs
      def self.call
        DownloadableResource.where("btrim(slug) = ''").update_all(slug: nil)
      end
    end
  end
end
