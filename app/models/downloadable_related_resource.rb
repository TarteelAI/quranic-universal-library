# == Schema Information
#
# Table name: downloadable_related_resources
#
#  id                       :integer          not null, primary key
#  downloadable_resource_id :integer
#  related_resource_id      :integer
#  relation_type            :string           default("pairs_with"), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#

class DownloadableRelatedResource < ApplicationRecord
  belongs_to :downloadable_resource, optional: true
  belongs_to :related_resource, class_name: 'DownloadableResource', optional: true

  enum :relation_type, { requires: 'requires', pairs_with: 'pairs_with', alternative: 'alternative',
                         supersedes: 'supersedes' }, validate: true

  validates :related_resource_id, uniqueness: { scope: :downloadable_resource_id }
end
