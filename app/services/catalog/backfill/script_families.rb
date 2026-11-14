# frozen_string_literal: true

module Catalog
  module Backfill
    # Drafts the script family of scripts, fonts and layouts (Catalog::Inference.script_family).
    module ScriptFamilies
      def self.call
        drafter = Drafter.new('script_families')
        Facts.load.sum do |resource, facts|
          drafter.fields(resource, 'script_family' => Inference.script_family(facts))
        end
      end
    end
  end
end
