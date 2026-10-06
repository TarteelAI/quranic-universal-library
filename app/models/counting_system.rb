# == Schema Information
#
# Table name: counting_systems
#
#  id             :bigint           not null, primary key
#  description_ar :text
#  description_en :text
#  is_reference   :boolean          default(FALSE), not null
#  name_ar        :string           not null
#  name_en        :string           not null
#  slug           :string           not null
#  total_ayahs    :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_counting_systems_on_slug  (slug) UNIQUE
#
# A madhhab of 'add al-ay: one of the six traditions of counting ayahs.
# Slugs are the qiraat-ayah-map ids verbatim. Kufi is the reference every
# cross-system mapping routes through. Never identify a system by its total:
# totals are read from the pinned dataset and may be disputed upstream.
class CountingSystem < QuranApiRecord
  SLUGS = %w[kufi madani-first madani-last makki basri dimashqi].freeze

  has_many :qiraat, class_name: 'Qiraah', inverse_of: :counting_system

  validates :slug, presence: true, uniqueness: true, inclusion: { in: SLUGS }
  validates :name_ar, :name_en, presence: true

  scope :reference, -> { where(is_reference: true) }

  def self.kufi
    find_by!(slug: 'kufi')
  end

  def to_s
    name_en
  end
end
