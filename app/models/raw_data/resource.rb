# == Schema Information
#
# Table name: raw_data_resources
#
#  id                  :bigint           not null, primary key
#  content_css_class   :string
#  description         :text
#  lang_iso            :string
#  name                :string
#  processed           :boolean          default(FALSE)
#  records_count       :integer          default(0)
#  sub_type            :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  language_id         :integer
#  resource_content_id :integer
#
# Indexes
#
#  index_raw_data_resources_on_sub_type  (sub_type)
#
class RawData::Resource < ApplicationRecord
  includes HasMetaData

  has_many :ayah_records
  belongs_to :resource_content
end
