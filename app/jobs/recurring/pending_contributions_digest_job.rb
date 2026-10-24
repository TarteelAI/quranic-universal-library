module Recurring
  class PendingContributionsDigestJob < ApplicationJob
    queue_as :default

    def perform
      counts = {
        translations: Draft::Translation.pending_contributions.count,
        tafsirs: Draft::Tafsir.pending_contributions.count,
        transliterations: Draft::Transliteration.pending_contributions.count,
        word_translations: Draft::WordTranslation.pending_contributions.count,
        word_transliterations: Draft::WordTransliteration.pending_contributions.count
      }
      return if counts.values.sum.zero?

      ContributionsMailer.pending_digest(User.find(1), counts).deliver_later
    end
  end
end
