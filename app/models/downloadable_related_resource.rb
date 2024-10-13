# == Schema Information
#
# Table name: downloadable_related_resources
#
#  id                       :bigint           not null, primary key
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  downloadable_resource_id :integer
#  related_resource_id      :integer
#
class DownloadableRelatedResource < ApplicationRecord
  belongs_to :downloadable_resource
  belongs_to :related_resource, class_name: 'DownloadableResource'
end
