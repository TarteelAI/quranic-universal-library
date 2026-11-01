class Draft::Lemma < ApplicationRecord
  include PaperTrailAttribution

  FIELDS = %w[text_madani text_clean].freeze

  belongs_to :lemma, class_name: '::Lemma'
  belongs_to :user, optional: true

  # Fixes suggested by users that aren't approved yet
  scope :pending_contributions, -> { where.not(user_id: nil).where(imported: false) }

  before_save { self.text_matched = matches_current? }

  def changed_fields
    fields = FIELDS.reject { |field| self["current_#{field}"].to_s.strip == self["draft_#{field}"].to_s.strip }
    fields << 'en_meanings' if Array(current_en_meanings) != Array(draft_en_meanings)
    fields
  end

  def matches_current?
    changed_fields.empty?
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

  def import!
    changes = changed_fields
    (changes & FIELDS).each { |field| lemma[field] = self["draft_#{field}"].to_s.strip }
    lemma.en_translations = Array(draft_en_meanings) if changes.include?('en_meanings')

    attribute_versions_to(user) do
      lemma.save(validate: false)
    end

    update_columns(imported: true)

    lemma
  end
end
