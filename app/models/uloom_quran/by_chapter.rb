# == Schema Information
#
# Table name: uloom_quran_by_chapters
#
#  id                  :bigint           not null, primary key
#  language_name       :string
#  meta_data           :jsonb            not null
#  text                :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  chapter_id          :integer
#  language_id         :integer
#  resource_content_id :integer
#
# Indexes
#
#  index_uloom_quran_by_chapters_on_chapter_id           (chapter_id)
#  index_uloom_quran_by_chapters_on_language_id          (language_id)
#  index_uloom_quran_by_chapters_on_language_name        (language_name)
#  index_uloom_quran_by_chapters_on_resource_content_id  (resource_content_id)
#  index_uloom_quran_by_chapters_on_text                 (text)
#
class UloomQuran::ByChapter < QuranApiRecord
  belongs_to :resource_content
  belongs_to :chapter
  belongs_to :language
end
