# == Schema Information
#
# Table name: mushaf_words
#
#  id                :bigint           not null, primary key
#  char_type_name    :string
#  css_class         :string
#  css_style         :string
#  line_number       :integer
#  page_number       :integer
#  position_in_line  :integer
#  position_in_page  :integer
#  position_in_verse :integer
#  text              :text
#  char_type_id      :integer
#  mushaf_id         :integer
#  verse_id          :integer
#  word_id           :integer
#
# Indexes
#
#  index_mushaf_words_on_mushaf_id_and_word_id  (mushaf_id,word_id)
#  index_on_mushad_word_position                (mushaf_id,verse_id,position_in_verse)
#  index_on_mushaf_word_position                (mushaf_id,verse_id,position_in_page)
#

class MushafWord < QuranApiRecord
  REGEXP_INDOPAK_WAQF_MARKS = Regexp.new(["ۛ", "ٚ", "ؔ", "ؕ", "ۥ", "ۚ", "۪", "۠", "ۙ", "ؗ", "۫", "ۘ", "ۗ", "۬", "ۙ", "۬", "ۦ"].join('|'))

  belongs_to :word
  belongs_to :verse
  belongs_to :mushaf
  belongs_to :char_type
  has_paper_trail on: %i[update], ignore: %i[created_at updated_at]

  has_one :word_translation, foreign_key: 'word_id', primary_key: 'word_id'

  def word?
    'word' == char_type_name
  end

  def has_waqf?
    text.match? REGEXP_INDOPAK_WAQF_MARKS
  end

  def word_position
    word.position
  end

  def image_url
    "#{CDN_HOST}/images/#{text}"
  end
end
