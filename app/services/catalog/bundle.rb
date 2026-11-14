# frozen_string_literal: true

module Catalog
  # The bundle tray's lookup. The bundle is a list of resource ids kept in the browser, so the
  # server never sees it until the tray asks what those ids are now: each published resource with
  # its published files, as its detail page lists them. An id that is not a published resource
  # comes back with no resource, and a restricted resource with no files (Catalog::ResourcePage
  # decides who may download it), so the tray shows them as unavailable instead of a dead link.
  # It knows nothing of the request or the session: the caller passes the signed-in user or nil.
  class Bundle
    MAX_IDS = 100

    Item = Data.define(:id, :resource, :files, :restricted)

    # The ids of a comma list, in order, without repeats, at most MAX_IDS.
    def self.ids(param)
      param.to_s.split(',').filter_map { |id| Integer(id, exception: false) }.select(&:positive?).uniq.first(MAX_IDS)
    end

    def initialize(ids, viewer:)
      @ids = ids
      @viewer = viewer
    end

    def items
      resources = DownloadableResource.published.where(id: @ids)
        .preload(downloadable_files: { file_attachment: :blob }).index_by(&:id)
      @ids.map do |id|
        resource = resources[id]
        next Item.new(id:, resource: nil, files: [], restricted: false) unless resource

        allowed = ResourcePage.download_allowed?(resource, @viewer)
        Item.new(id:, resource:, files: allowed ? files_of(resource) : [], restricted: !allowed)
      end
    end

    private

    # The published files that have a blob, in the detail page's order.
    def files_of(resource)
      resource.downloadable_files.select { |file| file.published && file.file.attached? }
        .sort_by { |file| [file.position || 0, file.id] }
        .map { |file| ResourcePage.download(file) }
    end
  end
end
