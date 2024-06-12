# == Schema Information
#
# Table name: pause_marks
#
#  id         :integer          not null, primary key
#  mark       :string
#  position   :integer
#  verse_key  :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  word_id    :integer
#
# Indexes
#
#  index_pause_marks_on_word_id  (word_id)
#
class PauseMark < ApplicationRecord
  belongs_to :word
end
