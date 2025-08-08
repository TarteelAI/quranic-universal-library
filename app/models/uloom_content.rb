# == Schema Information
#
# Table name: uloom_contents
#
#  id                  :bigint           not null, primary key
#  cardinality_type    :string
#  location            :string
#  location_range      :string
#  meta_data           :jsonb            not null
#  text                :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  chapter_id          :integer
#  resource_content_id :integer
#  verse_id            :integer
#  word_id             :integer
#
# Indexes
#
#  index_uloom_contents_on_cardinality_type     (cardinality_type)
#  index_uloom_contents_on_chapter_id           (chapter_id)
#  index_uloom_contents_on_location             (location)
#  index_uloom_contents_on_location_range       (location_range)
#  index_uloom_contents_on_resource_content_id  (resource_content_id)
#  index_uloom_contents_on_text                 (text)
#  index_uloom_contents_on_verse_id             (verse_id)
#  index_uloom_contents_on_word_id              (word_id)
#
class UloomContent < ApplicationRecord
  belongs_to :chapter
  belongs_to :resource_content
  belongs_to :verse, optional: true
  belongs_to :word,  optional: true
end
