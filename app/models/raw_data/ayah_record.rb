# == Schema Information
#
# Table name: raw_data_ayah_records
#
#  id                :bigint           not null, primary key
#  content_css_class :string
#  processed         :boolean          default(FALSE)
#  properties        :jsonb
#  text              :text
#  text_cleaned      :text
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  resource_id       :integer
#  verse_id          :integer
#
# Indexes
#
#  index_raw_data_ayah_records_on_verse_id  (verse_id)
#
class RawData::AyahRecord < ApplicationRecord
  belongs_to :resource, class_name: 'RawData::Resource'
  belongs_to :verse, optional: true
end
