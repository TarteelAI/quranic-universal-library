# == Schema Information
#
# Table name: important_notes
#
#  id         :bigint           not null, primary key
#  label      :string
#  text       :text
#  title      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer
#  verse_id   :integer
#  word_id    :integer
#

class ImportantNote < ApplicationRecord
  validates :title, :text, presence: true

  belongs_to :verse, optional: true
  belongs_to :word, optional: true
  belongs_to :user
end
