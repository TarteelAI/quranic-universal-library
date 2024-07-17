# == Schema Information
#
# Table name: resource_permissions
#
#  id                       :bigint           not null, primary key
#  contact_info             :string
#  copyright_notice         :string
#  permission_to_host       :integer          default("unknown")
#  permission_to_host_info  :text
#  permission_to_share      :integer          default("unknown")
#  permission_to_share_info :text
#  source_info              :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  resource_content_id      :integer
#
class ResourcePermission < ApplicationRecord
  belongs_to :resource_content

  enum permission_to_host: {
    unknown: 0,
    requested: 1,
    granted: 2,
    rejected: 3
  }, _prefix: :host_permission_is

  enum permission_to_share: {
    unknown: 0,
    requested: 1,
    granted: 2,
    rejected: 3
  }, _prefix: :share_permission_is
end
