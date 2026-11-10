# frozen_string_literal: true

module Catalog
  module Backfill
    # Drafts a one-line summary for resources that have none (Catalog::Inference.summary).
    module Summaries
      def self.call
        drafter = Drafter.new('summaries')
        Facts.load.sum do |resource, facts|
          drafter.fields(resource, 'short_summary' => Inference.summary(facts))
        end
      end
    end
  end
end
