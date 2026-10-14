# == Schema Information
#
# Table name: riwayat
#
#  id                   :bigint           not null, primary key
#  description          :text
#  enabled              :boolean          default(FALSE), not null
#  meta_data            :jsonb            not null
#  name                 :string
#  name_ar              :string
#  name_en              :string
#  recitations_count    :integer          default(0)
#  slug                 :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  default_numbering_id :integer
#  qiraah_id            :integer
#
# Indexes
#
#  index_riwayat_on_enabled    (enabled)
#  index_riwayat_on_qiraah_id  (qiraah_id)
#  index_riwayat_on_slug       (slug) UNIQUE
#
# A riwayah: the transmission of one qiraah through one rawi. This is the
# finest unit the Quranic text differs by, so scripts, mushafs, recitations
# and content overrides all key on it. Formerly qirat_types; the QiratType
# constant is an alias kept for one release.
#
# Two different reciters are called Khalaf: the rawi of Hamza (slug khalaf,
# qiraah hamza) and the tenth qari Khalaf al-Ashir, whose rawis are ishaq and
# idris. Never join them on the bare name.
class Riwayah < QuranApiRecord
  self.table_name = 'riwayat'

  SLUGS = %w[
    qalun warsh bazzi qunbul duri susi hisham ibn-dhakwan shuba hafs
    khalaf khallad abu-al-harith duri-kisai ibn-wardan ibn-jammaz ruways rawh ishaq idris
  ].freeze

  belongs_to :qiraah, optional: true
  has_many :audio_recitations, class_name: 'Audio::Recitation', foreign_key: :qirat_type_id
  has_many :verse_recitations, class_name: 'Recitation', foreign_key: :qirat_type_id
  has_many :mushafs, foreign_key: :qirat_type_id

  validates :slug, uniqueness: true, inclusion: { in: SLUGS }, allow_nil: true
  validates :name, presence: true

  scope :enabled, -> { where(enabled: true) }

  def self.hafs
    find_by!(slug: 'hafs')
  end

  def self.ransackable_attributes(_auth_object = nil)
    column_names
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[qiraah]
  end

  def unverified?
    meta_data['unverified'] == true
  end

  def update_recitation_count
    update_column :recitations_count, audio_recitations.size + verse_recitations.size
  end

  def to_s
    name_en.presence || name
  end
end
