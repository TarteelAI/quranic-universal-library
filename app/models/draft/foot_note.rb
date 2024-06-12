# == Schema Information
#
# Table name: draft_foot_notes
#
#  id                   :bigint           not null, primary key
#  current_text         :text
#  draft_text           :text
#  text_matched         :boolean
#  true                 :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  draft_translation_id :integer
#  resource_content_id  :integer
#
# Indexes
#
#  index_draft_foot_notes_on_draft_translation_id  (draft_translation_id)
#  index_draft_foot_notes_on_text_matched          (text_matched)
#

class Draft::FootNote < ApplicationRecord
  belongs_to :draft_translation, class_name: 'Draft::Translation'
  belongs_to :resource_content

  def language_name
    resource_content.try :language_name
  end
end
