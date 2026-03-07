# == Schema Information
#
# Table name: important_notes
#
#  id         :integer          not null, primary key
#  title      :string
#  text       :text
#  label      :string
#  user_id    :integer
#  verse_id   :integer
#  word_id    :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class ImportantNote < ApplicationRecord
  validates :title, :text, presence: true

  belongs_to :verse, optional: true
  belongs_to :resource_content, optional: true
  belongs_to :word, optional: true
  belongs_to :language, optional: true
  belongs_to :user, optional: true
end
