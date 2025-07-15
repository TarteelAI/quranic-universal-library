# == Schema Information
#
# Table name: uloom_quran_by_words
#
#  id                  :bigint           not null, primary key
#  from                :integer
#  language_name       :string
#  meta_data           :jsonb            not null
#  text                :text
#  to                  :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  chapter_id          :integer
#  language_id         :integer
#  resource_content_id :integer
#  verse_id            :integer
#  word_id             :integer
#
# Indexes
#
#  index_uloom_quran_by_words_on_chapter_id           (chapter_id)
#  index_uloom_quran_by_words_on_from                 (from)
#  index_uloom_quran_by_words_on_language_id          (language_id)
#  index_uloom_quran_by_words_on_language_name        (language_name)
#  index_uloom_quran_by_words_on_resource_content_id  (resource_content_id)
#  index_uloom_quran_by_words_on_text                 (text)
#  index_uloom_quran_by_words_on_to                   (to)
#  index_uloom_quran_by_words_on_verse_id             (verse_id)
#  index_uloom_quran_by_words_on_word_id              (word_id)
#
class UloomQuran::ByWord < QuranApiRecord
  belongs_to :resource_content
  belongs_to :chapter
  belongs_to :verse
  belongs_to :word
  belongs_to :language

end

