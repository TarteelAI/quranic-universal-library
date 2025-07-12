# == Schema Information
#
# Table name: roots
#
#  id                    :integer          not null, primary key
#  arabic_trilateral     :string
#  dictionary_image_path :string
#  en_translations       :jsonb
#  english_trilateral    :string
#  text_clean            :string
#  text_uthmani          :string
#  uniq_words_count      :integer
#  ur_translations       :jsonb
#  value                 :string
#  words_count           :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
# Indexes
#
#  index_roots_on_arabic_trilateral   (arabic_trilateral)
#  index_roots_on_english_trilateral  (english_trilateral)
#  index_roots_on_text_clean          (text_clean)
#  index_roots_on_text_uthmani        (text_uthmani)
#

class Root < QuranApiRecord
  has_many :words
  has_many :verses, through: :words

  def to_s
    text_uthmani
  end

  def english_translations
    Oj.load(en_translations.to_s) || []
  rescue Exception => e
    []
  end

  def update_stats
    update_columns(
      words_count: words.count,
      uniq_words_count: words.map(&:text_imlaei_simple).uniq.count
    )
  end
end