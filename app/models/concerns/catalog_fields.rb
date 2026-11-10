# frozen_string_literal: true

# Catalog fields of a DownloadableResource: lifecycle status, the recommended flag, script
# family, rendering method, display name and slug. They live here so the model file, which
# other work also changes, gains a single include line.
module CatalogFields
  extend ActiveSupport::Concern

  # The fields the catalog backfills draft. Their drafts are recorded in the review column
  # (Catalog::Review).
  DRAFTED_FIELDS = %w[status superseded_by_id recommended script_family rendering short_summary].freeze

  included do
    enum :status, { stable: 'stable', beta: 'beta', legacy: 'legacy', superseded: 'superseded' }, validate: true
    enum :script_family, { madani: 'madani', indopak: 'indopak', other: 'other' },
         prefix: true, validate: { allow_nil: true }
    enum :rendering, { unicode_font: 'unicode_font', glyph_page: 'glyph_page', image: 'image', svg: 'svg' },
         prefix: true, validate: { allow_nil: true }

    belongs_to :superseded_by, class_name: 'DownloadableResource', optional: true

    normalizes :slug, with: ->(slug) { slug.strip.presence }
    before_validation :assign_slug, if: -> { slug.nil? && name.present? }
    # find_by_slug_or_id! falls back to the id, so an all-digit slug would shadow a resource.
    validates :slug, format: { without: /\A\d+\z/, message: 'cannot be all digits' }, allow_nil: true

    # A blank summary is no summary, so the CMS form saving '' does not count as a change.
    normalizes :short_summary, with: ->(summary) { summary.strip.presence }
    # A drafted field changed by any save is a person's decision. Backfills write with
    # update_columns, which skips this.
    before_save :review_changed_fields

    before_destroy :delete_links_and_taggings
  end

  # False while the field (a column in DRAFTED_FIELDS, or `link:<id>`), or a field reviewed
  # together with it, holds a backfill's draft.
  def reviewed?(field)
    Catalog::Review.together(field.to_s).none? { |key| Catalog::Review.drafted(review).key?(key) }
  end

  # Moves one field's draft (or every draft) to reviewed, without changing any value, so the
  # backfills leave the field as it is. Returns the fields marked.
  def mark_reviewed!(field = nil)
    keys = field ? Catalog::Review.together(field.to_s) : Catalog::Review.drafted(review).keys
    update_columns(review: Catalog::Review.mark_reviewed(review, keys))
    keys
  end

  # Unique inside a resource type. Only names that repeat inside a type have their own display
  # name (Catalog::Backfill::DisplayNames); `name` stays the editor's.
  def display_name
    super.presence || name
  end

  private

  def review_changed_fields
    changed = DRAFTED_FIELDS.select { |field| will_save_change_to_attribute?(field) }
                            .flat_map { |field| Catalog::Review.together(field) }
    self.review = Catalog::Review.mark_reviewed(review, changed.uniq)
  end

  def assign_slug
    self.slug = Catalog::Slugs.generate(self) do |candidate|
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
