# == Schema Information
#
# Table name: quran_script_by_verses
#
#  id                  :bigint           not null, primary key
#  key                 :string
#  text                :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  qirat_id            :integer
#  resource_content_id :integer
#  verse_id            :integer
#
# Indexes
#
#  index_quran_script_by_verses_on_key                  (key)
#  index_quran_script_by_verses_on_qirat_id             (qirat_id)
#  index_quran_script_by_verses_on_resource_content_id  (resource_content_id)
#  index_quran_script_by_verses_on_text                 (text)
#  index_quran_script_by_verses_on_verse_id             (verse_id)
#
class QuranScript::ByVerse < QuranApiRecord
  belongs_to :resource_content
  belongs_to :verse
  belongs_to :qirat, class_name: 'QiratType'
end
