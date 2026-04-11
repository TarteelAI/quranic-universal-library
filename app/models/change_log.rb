class ChangeLog < ApplicationRecord
  belongs_to :user
  belongs_to :resource_content

  validates :title, :text, presence: true

  scope :latest, -> { order(created_at: :desc) }
  scope :published, -> { where(published: true) }
  scope :undelivered, -> { where(delivered: false) }

  def resource_type_slug
    resource_content&.sub_type.to_s.presence || resource_content&.resource_type.to_s.presence
  end

  def public_downloadable_resource
    resource_content&.primary_downloadable_resource
  end

  def content_html
    content.to_s
  end

  def content_plain_text
    content.to_plain_text
  end

  def deliverable?
    published? && !delivered?
  end
end
