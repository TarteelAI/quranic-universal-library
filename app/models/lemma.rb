# == Schema Information
#
# Table name: lemmas
#
#  id               :integer          not null, primary key
#  en_translations  :jsonb            not null
#  text_clean       :string
#  text_madani      :string
#  uniq_words_count :integer
#  words_count      :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class Lemma < QuranApiRecord
  has_many :words
  has_many :verses, through: :words

  def to_s
    text_madani
  end

  def update_stats
    update_columns(
      words_count: words.count,
      uniq_words_count: words.map(&:text_imlaei_simple).uniq.count
    )
  end
end
