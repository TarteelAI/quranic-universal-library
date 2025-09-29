# == Schema Information
#
# Table name: chapters
#
#  id                              :integer          not null, primary key
#  bismillah_pre                   :boolean
#  chapter_number                  :integer
#  color_header_chapter_glyph_code :string
#  hizbs_count                     :integer
#  name_arabic                     :string
#  name_complex                    :string
#  name_simple                     :string
#  pages                           :string
#  revelation_order                :integer
#  revelation_place                :string
#  rub_el_hizbs_count              :integer
#  rukus_count                     :integer
#  v1_chapter_glyph_code           :string
#  v2_chapter_glyph_code           :string
#  v4_chapter_glyph_code           :string
#  verses_count                    :integer
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
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

  serialize :pages

  alias_method :name, :id

  has_paper_trail on: :update, ignore: [:created_at, :updated_at]

  def humanize
    "#{chapter_number} - #{name_simple}"
  end

  def self.revelation_places
    ['madinah', 'makkah']
  end
end
