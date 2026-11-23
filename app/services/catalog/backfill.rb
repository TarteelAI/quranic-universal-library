# frozen_string_literal: true

module Catalog
  # The one catalog value that is stored: the slug, a public URL and API id that must not change
  # once it is set. `bin/rails catalog:backfill` gives a slug to every resource that has none,
  # from its display name (Catalog::Slugs), in id order and in one transaction. A blank slug
  # counts as none. A slug that is set is never changed and no row is deleted, so a second run
  # reports 0. Every other catalog field is computed when a page is read (Catalog::Derived).
  module Backfill
    # Step => the number of rows it changed.
    def self.run
      ApplicationRecord.transaction { { 'blank_slugs' => blank_slugs, 'slugs' => slugs } }
    end

    def self.blank_slugs
      DownloadableResource.where("btrim(slug) = ''").update_all(slug: nil)
    end

    def self.slugs
      taken = DownloadableResource.where.not(slug: nil).pluck(:slug).to_set
      catalog = Derived.new

      catalog.resources.select { |resource| resource.slug.nil? }.each do |resource|
        slug = Slugs.generate(catalog.of(resource).display_name, resource.resource_type) { |name| taken.include?(name) }
        resource.update_columns(slug: slug)
        taken << slug
      end.size
    end

    private_class_method :blank_slugs, :slugs
  end
end
