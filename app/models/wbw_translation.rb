# == Schema Information
#
# Table name: wbw_translations
#
#  id           :bigint           not null, primary key
#  approved     :boolean
#  text         :string
#  text_indopak :string
#  text_madani  :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  chapter_id   :integer
#  language_id  :integer
#  user_id      :integer
#  verse_id     :integer
#  word_id      :integer
#
# Indexes
#
#  index_wbw_translations_on_approved    (approved)
#  index_wbw_translations_on_chapter_id  (chapter_id)
#  index_wbw_translations_on_user_id     (user_id)
#  index_wbw_translations_on_verse_id    (verse_id)
#  index_wbw_translations_on_word_id     (word_id)
#

class WbwTranslation < ApplicationRecord
  belongs_to :word
  belongs_to :language

  delegate :text_imlaei, :ur_translation, :en_translation, :location, :char_type_name, to: :word

  before_save :use_default_text_if_blank!

  protected

  def use_default_text_if_blank!
    if text.blank?
      write_attribute(:text, default_text)
    end
  end

  def default_text
    if word_translations = word.word_translations.where(language: language).first
      word_translations.text
    end
  end
end
