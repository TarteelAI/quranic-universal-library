# == Schema Information
#
# Table name: licences
#
#  id                      :bigint           not null, primary key
#  allowed                 :text
#  allowed_with_permission :text
#  attribution             :text
#  conditions              :text
#  contact                 :string
#  copyright_holders       :text
#  credits                 :text
#  name                    :string           not null
#  prohibited              :text
#  short_name              :string
#  special_thanks          :text
#  summary                 :text
#  terms                   :text
#  url                     :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# A licence shared by many resources, e.g. CC BY 4.0, or one source's own
# terms that cover all of its Quran scripts and fonts. Attribution, credits
# and contact live here so each resource only has to pick the licence.
# The list columns hold one item per line.
class Licence < ApplicationRecord
  has_many :resource_permissions, dependent: :nullify

  validates :name, presence: true

  # resource_contents live in the Quran database, so this can't be a
  # has_many :through.
  def resource_contents
    ResourceContent.where(id: resource_permissions.pluck(:resource_content_id))
  end

  # Links the resources to this licence, creating their permission row if
  # needed. A resource on another licence moves to this one.
  def add_resource_contents(ids)
    transaction do
      ids.each do |id|
        ResourcePermission.find_or_initialize_by(resource_content_id: id).update!(licence: self)
      end
    end
  end

  def remove_resource_content(id)
    resource_permissions.where(resource_content_id: id).update_all(licence_id: nil)
  end

  def self.lines(text)
    text.to_s.lines.map { |line| line.strip.sub(/\A[-*•]\s*/, '') }.reject(&:blank?)
  end

  def allowed_list
    self.class.lines(allowed)
  end

  def allowed_with_permission_list
    self.class.lines(allowed_with_permission)
  end

  def prohibited_list
    self.class.lines(prohibited)
  end

  def conditions_list
    self.class.lines(conditions)
  end

  def copyright_holders_list
    self.class.lines(copyright_holders)
  end

  def display_name
    short_name.presence || name
  end
end
