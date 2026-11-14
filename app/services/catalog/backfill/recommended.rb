# frozen_string_literal: true

module Catalog
  module Backfill
    # Drafts the recommended flag (Catalog::Inference.recommended). It runs after the status,
    # script family and requires-link steps, whose values it reads.
    module Recommended
      def self.call
        drafter = Drafter.new('recommended')
        loaded = Facts.load
        ids = Inference.recommended(loaded.map(&:last)).to_set

        loaded.sum { |resource, _facts| drafter.fields(resource, 'recommended' => ids.include?(resource.id) || nil) }
      end
    end
  end
end
