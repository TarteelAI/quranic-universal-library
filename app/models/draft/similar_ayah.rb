class Draft::SimilarAyah < ApplicationRecord
  include PaperTrailAttribution

  belongs_to :verse
  belongs_to :chapter, optional: true
  belongs_to :user, optional: true

  # Fixes suggested by users that aren't approved yet
  scope :pending_contributions, -> { where.not(user_id: nil).where(imported: false) }

  before_save { self.text_matched = matches_current? }

  # Similar ayahs need a score of at least this to be listed both ways
  BOTH_WAYS_MIN_SCORE = 50

  def matches_current?
    added_verse_ids.blank? && removed_verse_ids.blank? && both_ways_verse_ids.blank?
  end

  def added_verses
    Verse.where(id: added_verse_ids).order(:verse_index)
  end

  def removed_verses
    Verse.where(id: removed_verse_ids).order(:verse_index)
  end

  def both_ways_verses
    Verse.where(id: both_ways_verse_ids).order(:verse_index)
  end

  def status
    if imported?
      'imported'
    elsif need_review?
      'needs review'
    else
      'approved'
    end
  end

  # Approves the added ayahs and unapproves the removed ones. A new match gets
  # its score and matched words when it's created. Ayahs asked to be listed
  # both ways also get this ayah as similar, if their match scores high enough.
  def import!
    skipped = []

    attribute_versions_to(user) do
      Morphology::MatchingVerse.transaction do
        added_verse_ids.each do |matched_verse_id|
          match = Morphology::MatchingVerse.find_or_initialize_by(verse_id: verse_id, matched_verse_id: matched_verse_id)
          match.update!(approved: true)
        end

        Morphology::MatchingVerse.where(verse_id: verse_id, matched_verse_id: removed_verse_ids).find_each do |match|
          match.update!(approved: false)
        end

        (both_ways_verse_ids - removed_verse_ids).each do |other_id|
          match = Morphology::MatchingVerse.find_by(verse_id: verse_id, matched_verse_id: other_id)
          if match.nil? || match.score.to_i < BOTH_WAYS_MIN_SCORE
            skipped << other_id
            next
          end

          Morphology::MatchingVerse.find_or_initialize_by(verse_id: other_id, matched_verse_id: verse_id).update!(approved: true)
        end
      end
    end

    update_columns(imported: true, meta_data: meta_data.merge('both_ways_skipped' => skipped).compact_blank)

    verse
  end
end
