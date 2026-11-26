# frozen_string_literal: true

module Catalog
  # The bundle tray's lookup (/bundle?ids=…, Catalog::BundlesController): each id the browser
  # holds, by resource type in taxonomy order (in the browser's order within a type, ids that are
  # no longer a resource last), and the download mode, which says whether a file needs an account.
  class BundleResource < ApplicationResource
    TYPE_ORDER = Taxonomy.types.each_with_index.to_h { |type, index| [type.key, index] }.freeze

    many :items, resource: BundleItemResource, source: proc {
      items.sort_by.with_index do |item, index|
        [TYPE_ORDER.fetch(item.resource&.resource_type, TYPE_ORDER.size), index]
      end
    }

    typelize download_mode: [:string, { enum: DownloadMode::MODES }]
    attribute(:download_mode) { DownloadMode.current }
  end
end
