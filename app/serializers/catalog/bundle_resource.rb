# frozen_string_literal: true

module Catalog
  # The bundle tray's lookup (/bundle?ids=…, Catalog::BundlesController): each id the browser
  # holds, in its order, and the download mode, which says whether a file needs an account.
  class BundleResource < ApplicationResource
    many :items, resource: BundleItemResource

    typelize download_mode: [:string, { enum: DownloadMode::MODES }]
    attribute(:download_mode) { DownloadMode.current }
  end
end
