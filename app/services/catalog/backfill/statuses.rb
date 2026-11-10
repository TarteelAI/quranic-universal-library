# frozen_string_literal: true

module Catalog
  module Backfill
    # Drafts legacy and superseded statuses, with the superseded-by pointer
    # (Catalog::Inference.status).
    module Statuses
      def self.call
        drafter = Drafter.new('statuses')
        loaded = Facts.load
        catalog = loaded.map(&:last)

        loaded.sum do |resource, facts|
          status, superseded_by_id = Inference.status(facts, catalog)
          drafter.fields(resource, 'status' => status, 'superseded_by_id' => superseded_by_id)
        end
      end
    end
  end
end
