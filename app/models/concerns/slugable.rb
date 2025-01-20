# frozen_string_literal: true

module Slugable
  extend ActiveSupport::Concern

  included do
    has_many :slugs

    def self.find_using_slug(slug)
      if slug.to_i.to_s == slug
        find_by(id: slug)
      else
        left_joins(:slugs)
          .where('slugs.slug = :slug', slug: slug)
          .first
      end
    end
  end
end
