# == Schema Information
#
# Table name: qiraat
#
#  id                 :bigint           not null, primary key
#  description        :text
#  name_ar            :string           not null
#  name_en            :string           not null
#  position           :integer
#  slug               :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  counting_system_id :integer
#
# Indexes
#
#  index_qiraat_on_counting_system_id  (counting_system_id)
#  index_qiraat_on_slug                (slug) UNIQUE
#
# One of the ten canonical readings, named after its qari. The counting
# system here is the one *attributed* to the qari (qiraat-ayah-map
# counting_system_associated_with_qari); what a printed edition of one of
# his rawis actually carries is a separate fact kept on the numbering.
class Qiraah < QuranApiRecord
  self.table_name = 'qiraat'

  SLUGS = %w[asim nafi ibn-kathir abu-amr ibn-amir hamza kisai abu-jafar yaqub khalaf].freeze

  belongs_to :counting_system, optional: true, inverse_of: :qiraat

  validates :slug, presence: true, uniqueness: true, inclusion: { in: SLUGS }
  validates :name_ar, :name_en, presence: true

  default_scope { order(:position) }

  def to_s
    name_en
  end
end
