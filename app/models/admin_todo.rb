# == Schema Information
#
# Table name: admin_todos
#
#  id                  :bigint           not null, primary key
#  description         :string
#  is_finished         :boolean
#  tags                :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  resource_content_id :integer
#
# Indexes
#
#  index_admin_todos_on_resource_content_id  (resource_content_id)
#

class AdminTodo < ApplicationRecord
  belongs_to :resource_content, optional: true
  after_create :notify_admin

  TAGS = [
    'import-issue',
    'new-translation',
    'update-translation',
    'translation-issue',
    'tafsir-issue'
  ]

  protected

  def notify_admin
    if(recipient = ENV['ADMIN_USER_EMAIL']).present?
      DeveloperMailer.notify(
        to: recipient,
        subject: 'QUL: QuranENC Sync issue',
        message: description
      ).deliver_later
    end
  end
end
