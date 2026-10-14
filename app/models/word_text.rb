# == Schema Information
#
# Table name: word_texts
#
#  marks       :jsonb            not null
#  text        :text             not null
#  text_simple :text
#  script_id   :integer          not null, primary key
#  word_id     :integer          not null, primary key
#
# Indexes
#
#  index_word_texts_on_word_id  (word_id)
#
# The form of one shared word in one script: the source of truth for every
# script stored as rows (the quran-text imports). No row means the riwayah
# does not read that word. `text` is the printed form with trailing marks
# reattached; `marks` lists the waqf/division/sajdah signs that trail it.
class WordText < QuranApiRecord
  self.primary_key = %i[script_id word_id]

  belongs_to :script
  belongs_to :word

  validates :text, presence: true

  scope :for_script, ->(script) { where(script_id: script) }
end
