# == Schema Information
#
# Table name: draft_contents
#
#  id                  :bigint           not null, primary key
#  current_text        :text
#  draft_text          :text
#  imported            :boolean
#  location            :string
#  meta_data           :jsonb
#  need_review         :boolean
#  text                :string
#  text_matched        :boolean
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  chapter_id          :integer
#  resource_content_id :integer
#  verse_id            :integer
#  word_id             :integer
#
# Indexes
#
#  index_draft_contents_on_chapter_id           (chapter_id)
#  index_draft_contents_on_imported             (imported)
#  index_draft_contents_on_location             (location)
#  index_draft_contents_on_need_review          (need_review)
#  index_draft_contents_on_resource_content_id  (resource_content_id)
#  index_draft_contents_on_text_matched         (text_matched)
#  index_draft_contents_on_verse_id             (verse_id)
#  index_draft_contents_on_word_id              (word_id)
#
class Draft::Content < ApplicationRecord
  belongs_to :word, optional: true
  belongs_to :verse
  belongs_to :chapter
  belongs_to :resource_content
end
