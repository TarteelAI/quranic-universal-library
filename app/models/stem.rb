# == Schema Information
#
# Table name: stems
#
#  id               :integer          not null, primary key
#  text_clean       :string
#  text_madani      :string
#  uniq_words_count :integer
#  words_count      :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class Stem < QuranApiRecord
  has_many :words
  has_many :verses, through: :words
end
