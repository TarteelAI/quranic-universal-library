# == Schema Information
#
# Table name: quran_script_by_verses
#
#  id                  :bigint           not null, primary key
#  key                 :string
#  text                :string
#  verse_number        :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  chapter_id          :integer
#  qirat_id            :integer
#  resource_content_id :integer
#  verse_id            :integer
#
# Indexes
#
#  index_quran_script_by_verses_on_chapter_id           (chapter_id)
#  index_quran_script_by_verses_on_key                  (key)
#  index_quran_script_by_verses_on_qirat_id             (qirat_id)
#  index_quran_script_by_verses_on_resource_content_id  (resource_content_id)
#  index_quran_script_by_verses_on_text                 (text)
#  index_quran_script_by_verses_on_verse_id             (verse_id)
#  index_quran_script_by_verses_on_verse_number         (verse_number)
#
class QuranScript::ByVerse < QuranApiRecord
  belongs_to :resource_content
  belongs_to :chapter
  belongs_to :verse, optional: true
  belongs_to :qirat, class_name: 'QiratType'
end
