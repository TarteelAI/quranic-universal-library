# frozen_string_literal: true

module Catalog
  module Backfill
    # Drafts how scripts, fonts and layouts are drawn (Catalog::Inference.rendering).
    module Renderings
      def self.call
        drafter = Drafter.new('renderings')
        Facts.load.sum do |resource, facts|
          drafter.fields(resource, 'rendering' => Inference.rendering(facts))
        end
      end
    end
  end
end
