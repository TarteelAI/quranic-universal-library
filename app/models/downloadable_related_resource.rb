# frozen_string_literal: true

# == Schema Information
#
# Table name: downloadable_related_resources
#
#  id                       :integer          not null, primary key
#  downloadable_resource_id :integer
#  related_resource_id      :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#

class DownloadableRelatedResource < ApplicationRecord
  belongs_to :downloadable_resource, optional: true
  belongs_to :related_resource, class_name: 'DownloadableResource', optional: true

  # No unique index: the table has repeated pairs, and the readers skip them (Catalog::Derived).
  # Checked on create only, so an existing repeated row can still be saved.
  validates :related_resource_id, uniqueness: { scope: :downloadable_resource_id }, on: :create # rubocop:disable Rails/UniqueValidationWithoutIndex

  # Whether a link is a requires-link is computed from the catalog (Catalog::Derived).
  after_commit { Catalog::Derived.reset }
end
