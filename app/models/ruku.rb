# == Schema Information
#
# Table name: rukus
#
#  id                :bigint           not null, primary key
#  ruku_number       :integer
#  surah_ruku_number :integer
#  verse_mapping     :json
#  verses_count      :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  first_verse_id    :integer
#  last_verse_id     :integer
#
# Indexes
#
#  index_rukus_on_first_verse_id_and_last_verse_id  (first_verse_id,last_verse_id)
#  index_rukus_on_ruku_number                       (ruku_number)
#

class Ruku < QuranApiRecord
  include NavigationSearchable
  has_many :verses, foreign_key: :ruku_number
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
