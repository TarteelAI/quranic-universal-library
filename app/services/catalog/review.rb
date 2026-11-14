# frozen_string_literal: true

module Catalog
  # The review column on a resource (`downloadable_resources.review`). `drafted` holds each value
  # a backfill inferred, with the backfill's name and time; `reviewed` holds the fields a person
  # has decided, so no backfill changes them again. A link is keyed `link:<related resource id>`.
  #
  #   { "drafted"  => { "rendering" => { "value" => "glyph_page", "by" => "renderings", "at" => "…" },
  #                     "link:249"  => { "value" => "requires", "replaced" => "pairs_with", … } },
  #     "reviewed" => { "status" => "…" } }
  module Review
    # A lifecycle status and its replacement are one decision, so they are reviewed together.
    TOGETHER = [%w[status superseded_by_id]].freeze

    module_function

    def drafted(review)
      review.fetch('drafted', {})
    end

    def reviewed(review)
      review.fetch('reviewed', {})
    end

    def together(key)
      TOGETHER.find { |keys| keys.include?(key) } || [key]
    end

    # The review column with `keys` moved from drafted to reviewed.
    def mark_reviewed(review, keys, at: Time.current)
      return review if keys.empty?

      build(drafted(review).except(*keys), reviewed(review).merge(keys.index_with { at.utc.iso8601 }))
    end

    def with_drafted(review, drafted)
      build(drafted, reviewed(review))
    end

    def build(drafted, reviewed)
      { 'drafted' => drafted, 'reviewed' => reviewed }.compact_blank
    end
  end
end
