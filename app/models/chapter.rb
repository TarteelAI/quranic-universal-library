# == Schema Information
#
# Table name: chapters
#
#  id                 :integer          not null, primary key
#  bismillah_pre      :boolean
#  chapter_number     :integer
#  hizbs_count        :integer
#  name_arabic        :string
#  name_complex       :string
#  name_simple        :string
#  pages              :string
#  revelation_order   :integer
#  revelation_place   :string
#  rub_el_hizbs_count :integer
#  rukus_count        :integer
#  verses_count       :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_chapters_on_chapter_number  (chapter_number)
#

class Chapter < QuranApiRecord
  include NavigationSearchable
  include Slugable
  has_many :verses, inverse_of: :chapter
  has_many :translated_names, as: :resource
  has_one :translated_name, as: :resource # for eager load
  has_many :chapter_infos
  has_one :default_slug, -> { where is_default: true}, class_name: 'Slug'

  serialize :pages

  alias_method :name, :id

  has_paper_trail on: :update, ignore: [:created_at, :updated_at]

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

  def humanize
    "#{chapter_number} - #{name_simple}"
  end
end
