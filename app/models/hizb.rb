# == Schema Information
#
# Table name: hizbs
#
#  id             :bigint           not null, primary key
#  hizb_number    :integer
#  verse_mapping  :jsonb
#  verses_count   :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  first_verse_id :integer
#  last_verse_id  :integer
#
# Indexes
#
#  index_hizbs_on_first_verse_id_and_last_verse_id  (first_verse_id,last_verse_id)
#  index_hizbs_on_hizb_number                       (hizb_number)
#

class Hizb < QuranApiRecord
  include NavigationSearchable
  has_many :verses, foreign_key: :manzil_number
  has_many :chapters, through: :verses
  belongs_to :first_verse, class_name: 'Verse'
  belongs_to :last_verse, class_name: 'Verse'

  scope :chapter_contains, lambda {|chapter_id|
    verses = Verse.order('verse_index ASC').where(chapter_id: chapter_id).select(:id)
    where('first_verse_id >= ? AND last_verse_id <= ?', verses.first.id, verses.last.id)
  }

  def self.ransackable_scopes(*)
    %i[chapter_contains]
  end
end
