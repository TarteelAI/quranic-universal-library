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

  def self.draft_resources
    counts = Draft::Content
               .group(:resource_content_id)
               .select("resource_content_id,
             COUNT(*) AS total_count,
             COUNT(CASE WHEN text_matched = true THEN 1 END) AS matched_count,
             COUNT(CASE WHEN text_matched = false THEN 1 END) AS not_matched_count,
             COUNT(CASE WHEN imported = true THEN 1 END) AS imported_count,
             COUNT(CASE WHEN imported = false THEN 1 END) AS not_imported_count,
             COUNT(CASE WHEN need_review = true THEN 1 END) AS need_review_count")

    resources = ResourceContent.where(id: counts.map(&:resource_content_id)).index_by(&:id)

    counts.map do |record|
      {
        resource: resources[record.resource_content_id],
        total_count: record.total_count.to_i,
        matched_count: record.matched_count.to_i,
        not_matched_count: record.not_matched_count.to_i,
        imported_count: record.imported_count.to_i,
        not_imported_count: record.not_imported_count.to_i,
        need_review_count: record.need_review_count.to_i
      }
    end
  end
end
