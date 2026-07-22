# == Schema Information
#
# Table name: user_projects
#
#  id                            :bigint           not null, primary key
#  additional_notes              :text
#  admin_notes                   :text
#  approved                      :boolean          default(FALSE)
#  description                   :text
#  language_proficiency          :text
#  motivation_and_goals          :text
#  reason_for_request            :text
#  review_process_acknowledgment :boolean
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  resource_content_id           :integer
#  user_id                       :integer
#

class UserProject < ApplicationRecord
  belongs_to :resource_content, optional: true
  belongs_to :user, optional: true

  validates :reason_for_request, :language_proficiency, :motivation_and_goals, presence: true
  validates :review_process_acknowledgment, presence: {message: 'Please check the review process acknowledge'}
  validate :unique_request_per_resource

  def get_resource_content
    resource_content
  end

  private

  def unique_request_per_resource
    return if user_id.blank? || resource_content_id.blank?

    scope = UserProject.where(user_id: user_id, resource_content_id: resource_content_id)
    scope = scope.where.not(id: id) if persisted?

    errors.add(:base, "You have already requested access to this resource.") if scope.exists?
  end
end
