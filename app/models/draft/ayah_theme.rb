class Draft::AyahTheme < ApplicationRecord
  include PaperTrailAttribution

  belongs_to :ayah_theme, class_name: '::AyahTheme'
  belongs_to :chapter
  belongs_to :user, optional: true

  # Fixes suggested by users that aren't approved yet
  scope :pending_contributions, -> { where.not(user_id: nil).where(imported: false) }

  before_save { self.text_matched = matches_current? }

  def theme_changed?
    current_theme.to_s.strip != draft_theme.to_s.strip
  end

  def keywords_changed?
    Array(current_keywords) != Array(draft_keywords)
  end

  def range_changed?
    current_verse_id_from != draft_verse_id_from || current_verse_id_to != draft_verse_id_to
  end

  def matches_current?
    !theme_changed? && !keywords_changed? && !range_changed?
  end

  def current_range_label
    range_label(current_verse_id_from, current_verse_id_to)
  end

  def draft_range_label
    range_label(draft_verse_id_from, draft_verse_id_to)
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

  # Themes that overlap the new range are shortened, or removed when nothing is left of them
  def import!
    theme = ayah_theme

    attribute_versions_to(user) do
      ::AyahTheme.transaction do
        theme.theme = draft_theme.to_s.strip
        theme.keywords = Array(draft_keywords)
        theme.set_range(draft_verse_id_from, draft_verse_id_to)
        theme.save!(validate: false)

        theme.overlapping_themes.each do |other|
          if other.verse_id_from >= theme.verse_id_from && other.verse_id_to <= theme.verse_id_to
            other.destroy!
          elsif other.verse_id_from < theme.verse_id_from
            other.set_range(other.verse_id_from, theme.verse_id_from - 1)
            other.save!(validate: false)
          else
            other.set_range(theme.verse_id_to + 1, other.verse_id_to)
            other.save!(validate: false)
          end
        end
      end
    end

    update_columns(imported: true)

    theme
  end

  private

  def range_label(from, to)
    keys = Verse.where(id: [from, to]).order(:verse_index).pluck(:verse_key)
    keys.uniq.join(' - ')
  end
end
