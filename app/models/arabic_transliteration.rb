# == Schema Information
#
# Table name: arabic_transliterations
#
#  id             :integer          not null, primary key
#  continuous     :boolean
#  indopak_text   :string
#  page_number    :integer
#  position_x     :integer
#  position_y     :integer
#  text           :string
#  ur_translation :string
#  zoom           :float
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  verse_id       :integer
#  word_id        :integer
#
# Indexes
#
#  index_arabic_transliterations_on_verse_id  (verse_id)
#  index_arabic_transliterations_on_word_id   (word_id)
#
class ArabicTransliteration < QuranApiRecord
  belongs_to :word, optional: true
  belongs_to :verse
  has_paper_trail on: :update, ignore: [:created_at, :updated_at]

  delegate :location, to: :word
  
  def name
    text
  end

  def text_simple
    word&.text_uthmani_simple
  end
end
