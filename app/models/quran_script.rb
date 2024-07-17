# == Schema Information
#
# Table name: quran_scripts
#
#  id                  :bigint           not null, primary key
#  occurrence_count    :string
#  qirat_name          :string
#  record_type         :string
#  script_name         :string
#  text                :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  record_id           :bigint
#  resource_content_id :integer
#
# Indexes
#
#  index_quran_scripts_on_record               (record_type,record_id)
#  index_quran_scripts_on_resource_content_id  (resource_content_id)
#
class QuranScript < QuranApiRecord
  belongs_to :record, polymorphic: true
  belongs_to :resource_content, optional: true
end
