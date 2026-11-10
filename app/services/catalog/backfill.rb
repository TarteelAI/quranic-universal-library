# frozen_string_literal: true

module Catalog
  # The catalog backfills, run in order in one transaction by `bin/rails catalog:backfill`.
  # Each step is idempotent, keyed on stable fields (ids, existing slugs), never overwrites a
  # value that is already set, and returns the number of rows it changed, so a second run
  # reports 0 for every step.
  #
  # The first steps are mechanical. The later ones draft values the data implies but no field
  # held (Catalog::Inference, written through Backfill::Drafter): each drafted value is recorded
  # in the resource's review column, and a value a person set or reviewed is never changed.
  # They run in this order because each reads what the steps before it drafted.
  module Backfill
    STEPS = [
      BlankSlugs, DisplayNames, Slugs, RelatedLinks, Taggings,
      ScriptFamilies, Renderings, Statuses, RequiresLinks, Recommended, Summaries
    ].freeze

    def self.run
      ApplicationRecord.transaction do
        STEPS.to_h { |step| [step.name.demodulize.underscore, step.call] }
      end
    end
  end
end
