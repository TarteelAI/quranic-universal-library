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

  # A link changed or deleted outside a backfill is a person's decision: the source resource's
  # review column marks it reviewed, so the backfills do not restore or retype it.
  after_update :review_previous_link, if: lambda {
    saved_change_to_relation_type? || saved_change_to_related_resource_id? || saved_change_to_downloadable_resource_id?
  }
  after_destroy { review_link(downloadable_resource_id, related_resource_id) }

  private

  def review_previous_link
    review_link(downloadable_resource_id_before_last_save, related_resource_id_before_last_save)
  end

  def review_link(source_id, related_id)
    DownloadableResource.find_by(id: source_id)&.mark_reviewed!("link:#{related_id}")
  end
end
