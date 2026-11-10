# frozen_string_literal: true

module Catalog
  # The catalog backfills, run in order in one transaction by `bin/rails catalog:backfill`.
  # Each step is idempotent, keyed on stable fields (ids, existing slugs), never overwrites a
  # value that is already set, and returns the number of rows it changed, so a second run
  # reports 0 for every step.
  module Backfill
    STEPS = [BlankSlugs, DisplayNames, Slugs, RelatedLinks, Taggings].freeze

    def self.run
      ApplicationRecord.transaction do
        STEPS.to_h { |step| [step.name.demodulize.underscore, step.call] }
      end
    end
  end
end
