# == Schema Information
#
# Table name: user_projects
#
#  id                  :bigint           not null, primary key
#  admin_notes         :text
#  description         :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  resource_content_id :integer
#  user_id             :integer
#

class UserProject < ApplicationRecord
  belongs_to :resource_content
  belongs_to :user

  def get_resource_content
    resource_content
  end
end
