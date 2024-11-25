# == Schema Information
#
# Table name: downloadable_resource_taggings
#
#  id                           :bigint           not null, primary key
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  downloadable_resource_id     :integer          not null
#  downloadable_resource_tag_id :integer          not null
#
# Indexes
#
#  index_downloadable_resource_tag  (downloadable_resource_id,downloadable_resource_tag_id)
#
class DownloadableResourceTagging < ApplicationRecord
  belongs_to :downloadable_resource
  belongs_to :downloadable_resource_tag
end
