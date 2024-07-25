# == Schema Information
#
# Table name: wbw_texts
#
#  id           :bigint           not null, primary key
#  approved     :boolean          default(FALSE)
#  is_updated   :boolean          default(FALSE)
#  text_imlaei  :string
#  text_indopak :string
#  text_uthmani :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  verse_id     :integer
#  word_id      :integer
#
# Indexes
#
#  index_wbw_texts_on_verse_id  (verse_id)
#  index_wbw_texts_on_word_id   (word_id)
#

class WbwText < ApplicationRecord
  belongs_to :word
  belongs_to :verse
end
