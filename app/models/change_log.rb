class ChangeLog < ApplicationRecord
  belongs_to :user
  belongs_to :resource_content, optional: true

  validates :title, :text, :excerpt, presence: true

  scope :latest, -> { order(created_at: :desc) }
  scope :published, -> { where(published: true) }

  def resource_type_slug
    if resource_content
      resource_content.sub_type.to_s.presence || resource_content.resource_type.to_s.presence
    end
  end

  def public_downloadable_resource
    resource_content&.primary_downloadable_resource
  end
end
