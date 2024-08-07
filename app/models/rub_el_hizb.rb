# == Schema Information
#
# Table name: rub_el_hizbs
#
#  id                 :bigint           not null, primary key
#  rub_el_hizb_number :integer
#  verse_mapping      :json
#  verses_count       :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  first_verse_id     :integer
#  last_verse_id      :integer
#
# Indexes
#
#  index_rub_el_hizbs_on_first_verse_id_and_last_verse_id  (first_verse_id,last_verse_id)
#  index_rub_el_hizbs_on_rub_el_hizb_number                (rub_el_hizb_number)
#

class RubElHizb < QuranApiRecord
  include NavigationSearchable
  has_many :verses, foreign_key: :rub_el_hizb_number
  has_many :chapters, through: :verses
  belongs_to :first_verse, class_name: 'Verse'
  belongs_to :last_verse, class_name: 'Verse'

  scope :chapter_cont, lambda {|chapter_id|
    verses = Verse.order('verse_index ASC').where(chapter_id: chapter_id).select(:id)
    where('? >= first_verse_id AND ? <= last_verse_id', verses.first.id, verses.last.id)
  }

  def self.ransackable_scopes(*)
    %i[chapter_cont]
  end
end
