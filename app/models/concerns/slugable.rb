# frozen_string_literal: true

module Slugable
  extend ActiveSupport::Concern

  included do
    has_many :slugs
    has_one :default_slug, -> { where is_default: true}, class_name: 'Slug'

    def self.find_using_slug(slug)
      joins(:slugs).where('slugs.slug': slug).first || find_by(id: slug)
    end
  end

  def add_slug(name, locale = 'en', is_default = false)
    require 'babosa'
    slug = slugs.where(slug: name.to_slug.normalize.transliterate.to_s, locale: locale).first_or_initialize

    if slug.locale.blank?
      slug.locale = 'en'
    end
    lang = Language.find_by_iso_code(slug.locale)

    slug.is_default = is_default
    slug.name = name
    slug.save
    slug.language = lang
    slug.language_priority = lang.english? ? 1 : 3 # Sorting slugs in desc order in the api. English should have least priority
    slug.save(validate: false)
  end
end
