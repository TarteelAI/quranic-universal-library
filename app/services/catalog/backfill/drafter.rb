# frozen_string_literal: true

module Catalog
  module Backfill
    # Writes inferred values the way every drafting backfill must. A field a person reviewed or
    # set is never changed. A field that holds its default, or this backfill's own draft, takes
    # the inferred value, or goes back to its default when nothing is inferred any more, and the
    # review column records the draft. A draft whose value was changed without the model (so
    # without the review rule) is treated as the person's decision. Writes use update_columns, so
    # the model's review rule does not run. Each call returns the number of rows it changed.
    class Drafter
      DEFAULTS = {
        'status' => 'stable', 'superseded_by_id' => nil, 'recommended' => false,
        'script_family' => nil, 'rendering' => nil, 'short_summary' => nil
      }.freeze

      def initialize(name)
        @name = name
        @at = Time.current.utc.iso8601
      end

      # `values` maps fields to the inferred value, or nil for none. They are written together or
      # not at all.
      def fields(resource, values)
        drafted = Review.drafted(resource.review)
        keys = values.keys
        return 0 if keys.any? { |key| Review.reviewed(resource.review).key?(key) }
        stale = keys.any? { |key| drafted.key?(key) && drafted.dig(key, 'value') != resource[key] }
        return reviewed(resource, keys) if stale
        return 0 unless keys.all? { |key| drafted.key?(key) || default?(resource, key) }

        columns = values.select { |key, value| value || drafted.key?(key) }
                        .to_h { |key, value| [key, value.nil? ? DEFAULTS.fetch(key) : value] }
        entries = values.compact.to_h { |key, value| [key, entry(drafted[key], value)] }
        write(resource, columns, drafted.except(*keys).merge(entries))
      end

      # A requires-link from the resource to `related_id` when `inferred`, else none. An existing
      # untyped (pairs_with) link is retyped and restored on retraction; a link the backfill made
      # is deleted on retraction.
      def link(resource, related_id, inferred)
        key = "link:#{related_id}"
        drafted = Review.drafted(resource.review)
        return 0 if Review.reviewed(resource.review).key?(key)

        link = resource.downloadable_related_resources.find { |row| row.related_resource_id == related_id }
        draft = drafted[key]
        return reviewed(resource, [key]) if draft && draft['value'] != link&.relation_type
        # A link typed by a person.
        return 0 if draft.nil? && link && !link.pairs_with?
        # Already drafted, or nothing of this backfill's to retract.
        return 0 if inferred ? draft : draft.nil?

        if inferred
          replaced = link&.relation_type
          link ? link.update_columns(relation_type: 'requires') : create_link(resource, related_id)
          entry = { 'value' => 'requires', 'replaced' => replaced, 'by' => @name, 'at' => @at }
          1 + write(resource, {}, drafted.merge(key => entry))
        else
          draft['replaced'] ? link.update_columns(relation_type: draft['replaced']) : link.delete
          1 + write(resource, {}, drafted.except(key))
        end
      end

      private

      def default?(resource, key)
        DEFAULTS.fetch(key).nil? ? resource[key].blank? : resource[key] == DEFAULTS.fetch(key)
      end

      def entry(current, value)
        return current if current && current['value'] == value

        { 'value' => value, 'by' => @name, 'at' => @at }
      end

      def reviewed(resource, keys)
        resource.update_columns(review: Review.mark_reviewed(resource.review, keys))
        1
      end

      def write(resource, columns, drafted)
        review = Review.with_drafted(resource.review, drafted)
        changes = columns.reject { |key, value| resource[key] == value }
        return 0 if changes.empty? && review == resource.review

        resource.update_columns(**changes, review: review)
        1
      end

      def create_link(resource, related_id)
        DownloadableRelatedResource.insert!(
          { downloadable_resource_id: resource.id, related_resource_id: related_id, relation_type: 'requires' }
        )
        resource.downloadable_related_resources.reset
      end
    end
  end
end
