# == Schema Information
#
# Table name: juzs
#
#  id             :integer          not null, primary key
#  juz_number     :integer
#  verse_mapping  :json
#  verses_count   :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  first_verse_id :integer
#  last_verse_id  :integer
#
# Indexes
#
#  index_juzs_on_first_verse_id  (first_verse_id)
#  index_juzs_on_juz_number      (juz_number)
#  index_juzs_on_last_verse_id   (last_verse_id)
#
class Juz < QuranApiRecord
  include NavigationSearchable
  include HasVerseMapping
  has_many :verses, foreign_key: :juz_number
  has_many :chapters, through: :verses

  belongs_to :first_verse, class_name: 'Verse'
  belongs_to :last_verse, class_name: 'Verse'
end
