# frozen_string_literal: true

# Catalog fields of a DownloadableResource. The slug is stored. The display name, script family,
# rendering, lifecycle status and replacement and the summary of a resource without one are
# computed from the catalog when they are read (Catalog::Derived), where an
# editor's `meta_data` key overrides the computed value. They live here so the model file, which
# other work also changes, gains a single include line.
module CatalogFields
  extend ActiveSupport::Concern

  included do
    normalizes :slug, with: ->(slug) { slug.strip.presence }
    before_validation :assign_slug, if: -> { slug.nil? && name.present? }
    # find_by_slug_or_id! falls back to the id, so an all-digit slug would shadow a resource.
    validates :slug, format: { without: /\A\d+\z/, message: 'cannot be all digits' }, allow_nil: true

    # A blank summary is no summary.
    normalizes :short_summary, with: ->(summary) { summary.strip.presence }

    before_destroy :delete_links_and_taggings
    # The fields of every resource are computed from the whole catalog, so any change drops it.
    after_commit { Catalog::Derived.reset }
  end

  delegate :script_family, :rendering, :status, to: :catalog_fields

  # The resource that replaces this one, or nil.
  def superseded_by
    Catalog::Derived.current.superseded_by(self)
  end

  Catalog::Derived::STATUSES.each do |status|
    define_method(:"#{status}?") { self.status == status }
  end

  # The display name. Not called `display_name`: ActiveAdmin labels a record with that first, and the
  # CMS label is the plain `name`, which needs no catalog.
  def catalog_name
    catalog_fields.display_name
  end

  # The editor's summary, else one plain sentence from the resource's facts.
  def summary
    short_summary.presence || Catalog::Derived.current.summary(self)
  end

  private

  def catalog_fields
    Catalog::Derived.current.of(self)
  end

  # A new resource's slug comes from the name the editor gave it.
  def assign_slug
    override = meta_value(Catalog::Derived::OVERRIDES.fetch(:display_name))
    name = Catalog::Derived.display_name_override(override) || self.name
    self.slug = Catalog::Slugs.generate(name, resource_type) do |candidate|
      DownloadableResource.where.not(id: id).exists?(slug: candidate)
    end
  end

  def delete_links_and_taggings
    DownloadableResourceTagging.where(downloadable_resource_id: id).delete_all
    DownloadableRelatedResource.where(downloadable_resource_id: id)
      .or(DownloadableRelatedResource.where(related_resource_id: id))
      .delete_all
  end
end
