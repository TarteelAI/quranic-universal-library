# == Schema Information
#
# Table name: user_projects
#
#  id                  :bigint           not null, primary key
#  admin_notes         :text
#  approved            :boolean          default(FALSE)
#  description         :text
#  request_message     :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  resource_content_id :integer
#  user_id             :integer
#

class UserProject < ApplicationRecord
  belongs_to :resource_content
  belongs_to :user

  validates :reason_for_request, :language_proficiency, :motivation_and_goals, presence: true

  validates :review_process_acknowledgment, presence: {message: 'Please check the review process acknowledge'}

  def get_resource_content
    resource_content
  end
end
