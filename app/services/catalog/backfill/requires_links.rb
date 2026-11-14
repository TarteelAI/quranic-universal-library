# frozen_string_literal: true

module Catalog
  module Backfill
    # Drafts the requires-link from each layout and glyph script to its font
    # (Catalog::Inference.required_font), and retracts its own links the data no longer implies.
    module RequiresLinks
      def self.call
        drafter = Drafter.new('requires_links')
        loaded = Facts.load
        fonts = loaded.map(&:last).select { |facts| facts.type == 'font' }

        loaded.sum do |resource, facts|
          font_id = Inference.required_font(facts, fonts)
          drafted = Review.drafted(resource.review).keys.grep(/\Alink:/).map { |key| key.delete_prefix('link:').to_i }

          (drafted | [font_id].compact).sum { |related_id| drafter.link(resource, related_id, related_id == font_id) }
        end
      end
    end
  end
end
