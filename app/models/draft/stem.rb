class Draft::Stem < ApplicationRecord
  include PaperTrailAttribution

  FIELDS = %w[text_madani text_clean].freeze

  belongs_to :stem, class_name: '::Stem'
  belongs_to :user, optional: true

  # Fixes suggested by users that aren't approved yet
  scope :pending_contributions, -> { where.not(user_id: nil).where(imported: false) }

  before_save { self.text_matched = matches_current? }

  def changed_fields
    FIELDS.reject { |field| self["current_#{field}"].to_s.strip == self["draft_#{field}"].to_s.strip }
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
    changed_fields.each { |field| stem[field] = self["draft_#{field}"].to_s.strip }

    attribute_versions_to(user) do
      stem.save(validate: false)
    end

    update_columns(imported: true)

    stem
  end
end
