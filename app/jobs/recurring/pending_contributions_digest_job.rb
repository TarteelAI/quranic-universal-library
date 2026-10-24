module Recurring
  class PendingContributionsDigestJob < ApplicationJob
    queue_as :default

    def perform
      counts = {
        translations: Draft::Translation.pending_contributions.count,
        tafsirs: Draft::Tafsir.pending_contributions.count
      }
      return if counts.values.sum.zero?

      User.where(id: 1).or(User.is_super_admin).find_each do |user|
        ContributionsMailer.pending_digest(user, counts).deliver_later
      end
    end
  end
end
