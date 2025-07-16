# == Schema Information
#
# Table name: quran_script_by_words
#
#  id                  :bigint           not null, primary key
#  key                 :string
#  text                :string
#  verse_number        :integer
#  word_number         :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  chapter_id          :integer
#  qirat_id            :string
#  resource_content_id :string
#  verse_id            :string
#  word_id             :string
#
# Indexes
#
#  index_quran_script_by_words_on_chapter_id           (chapter_id)
#  index_quran_script_by_words_on_key                  (key)
#  index_quran_script_by_words_on_qirat_id             (qirat_id)
#  index_quran_script_by_words_on_resource_content_id  (resource_content_id)
#  index_quran_script_by_words_on_text                 (text)
#  index_quran_script_by_words_on_verse_id             (verse_id)
#  index_quran_script_by_words_on_verse_number         (verse_number)
#  index_quran_script_by_words_on_word_id              (word_id)
#  index_quran_script_by_words_on_word_number          (word_number)
#
class QuranScript::ByWord < QuranApiRecord
  belongs_to :resource_content
  belongs_to :word, optional: true
  belongs_to :verse, optional: true
  belongs_to :chapter
  belongs_to :qirat, class_name: 'QiratType'
end
