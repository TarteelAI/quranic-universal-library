# == Schema Information
#
# Table name: resource_permissions
#
#  id                       :bigint           not null, primary key
#  attribution              :text
#  contact_info             :string
#  copyright_notice         :string
#  custom_terms             :text
#  permission_to_host       :integer          default("unknown")
#  permission_to_host_info  :text
#  permission_to_share      :integer          default("unknown")
#  permission_to_share_info :text
#  source_info              :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  licence_id               :bigint
#  resource_content_id      :integer
#
# permission_to_* and their *_info, source_info and contact_info are internal
# notes. copyright_notice, the licence, attribution and custom_terms are shown
# publicly on the resource's Licence tab.
class ResourcePermission < ApplicationRecord
  belongs_to :resource_content
  belongs_to :licence, optional: true

  enum :permission_to_host, {
    unknown: 0,
    requested: 1,
    granted: 2,
    rejected: 3
  }, prefix: :host_permission_is

  enum :permission_to_share, {
    unknown: 0,
    requested: 1,
    granted: 2,
    rejected: 3
  }, prefix: :share_permission_is

  # A resource can word its own attribution, e.g. naming the script rather
  # than the whole package; otherwise the licence's is used.
  def attribution_text
    attribution.presence || licence&.attribution
  end

  def licence_details?
    licence.present? || attribution.present? || custom_terms.present?
  end
end
