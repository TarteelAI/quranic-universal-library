# frozen_string_literal: true

module Content
  # The published changelog entries (ChangeLog), newest first, a page at a time, and one entry.
  # Each names its resource and links to the resource's detail page while a published
  # DownloadableResource holds it. The entries and resources (CMS) and the resource contents
  # (content database) are loaded in separate queries.
  class Changelog
    PER_PAGE = 20

    Entry = Data.define(:id, :title, :excerpt, :text, :date, :resource)
    Resource = Data.define(:name, :path)
    Page = Data.define(:entries, :page, :pages)

    # `param` is the `page` query value; a page that is not a positive number in range is not found.
    def self.page(param)
      pages = [(scope.count / PER_PAGE.to_f).ceil, 1].max
      number = param.nil? ? 1 : param.to_s[/\A\d+\z/].to_i
      raise ActiveRecord::RecordNotFound unless number.between?(1, pages)

      Page.new(entries: entries(scope.offset((number - 1) * PER_PAGE).limit(PER_PAGE)), page: number, pages:)
    end

    def self.find(id)
      entries(scope.where(id:)).first || raise(ActiveRecord::RecordNotFound)
    end

    def self.scope
      ChangeLog.published.order(created_at: :desc, id: :desc)
    end

    def self.entries(relation)
      rows = relation.preload(:resource_content).to_a
      published = published_resources(rows.map(&:resource_content_id).uniq)
      rows.map do |row|
        Entry.new(id: row.id, title: row.title, excerpt: row.excerpt, text: row.text, date: row.created_at.to_date,
                  resource: resource(row.resource_content, published[row.resource_content_id]),)
      end
    end

    # The first published resource of each resource content, by resource content id.
    def self.published_resources(resource_content_ids)
      resources = DownloadableResource.published.where(resource_content_id: resource_content_ids).order(:id)
      resources.group_by(&:resource_content_id).transform_values(&:first)
    end

    def self.resource(content, published)
      return if content.nil?

      path = published && routes.catalog_resource_path(published.resource_type, published.to_param)
      Resource.new(name: content.name, path:)
    end

    def self.routes
      Rails.application.routes.url_helpers
    end

    private_class_method :scope, :entries, :published_resources, :resource, :routes
  end
end
