class Draft::Root < ApplicationRecord
  include PaperTrailAttribution

  FIELDS = %w[arabic_trilateral english_trilateral text_uthmani].freeze
  MEANINGS = %w[en_meanings ur_meanings].freeze

  belongs_to :root, class_name: '::Root'
  belongs_to :user, optional: true

  # Fixes suggested by users that aren't approved yet
  scope :pending_contributions, -> { where.not(user_id: nil).where(imported: false) }

  before_save { self.text_matched = matches_current? }

  def changed_fields
    FIELDS.reject { |field| self["current_#{field}"].to_s.strip == self["draft_#{field}"].to_s.strip } +
      MEANINGS.reject { |field| Array(self["current_#{field}"]) == Array(self["draft_#{field}"]) }
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

    if changes.include?('arabic_trilateral')
      root.arabic_trilateral = root.value = root.text_clean = draft_arabic_trilateral
    end
    root.english_trilateral = draft_english_trilateral if changes.include?('english_trilateral')
    root.text_uthmani = draft_text_uthmani.presence if changes.include?('text_uthmani')
    # Meanings are kept as a JSON string, like the rest of the roots
    root.en_translations = meanings_json(draft_en_meanings) if changes.include?('en_meanings')
    root.ur_translations = meanings_json(draft_ur_meanings) if changes.include?('ur_meanings')

    attribute_versions_to(user) do
      root.save(validate: false)
    end

    update_columns(imported: true)

    root
  end

  private

  def meanings_json(meanings)
    Array(meanings).to_json if Array(meanings).any?
  end
end
