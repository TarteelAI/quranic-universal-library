class ChangeLogDeliveryJob < ApplicationJob
  queue_as :default

  def perform(change_log_id)
    change_log = ChangeLog.includes(:resource_content, :rich_text_content).find(change_log_id)

    change_log.with_lock do
      return unless change_log.deliverable?

      User.where.not(email: [nil, '']).find_each do |user|
        ChangeLogMailer.announcement(change_log, user).deliver_later
      end

      change_log.update!(delivered: true, delivered_at: Time.current)
    end
  end
end
