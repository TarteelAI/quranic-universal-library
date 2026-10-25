class Draft::SurahInfo < ApplicationRecord
  include PaperTrailAttribution
  include DraftResourceStats

  belongs_to :resource_content
  belongs_to :chapter
  belongs_to :user, optional: true

  before_save :refresh_current_text, if: :chapter_id_changed?
  before_save { self.text_matched = matches_current? }

  def original_surah_info
    ::ChapterInfo.find_by(chapter_id: chapter_id, resource_content_id: resource_content_id)
  end

  def previous_surah_draft
    Draft::SurahInfo
      .where(resource_content_id: resource_content_id)
      .where('chapter_id < ?', chapter_id)
      .order(chapter_id: :desc)
      .first
  end

  def next_surah_draft
    Draft::SurahInfo
      .where(resource_content_id: resource_content_id)
      .where('chapter_id > ?', chapter_id)
      .order(:chapter_id)
      .first
  end

  def import!
    info = ::ChapterInfo.where(
      chapter_id: chapter_id,
      resource_content_id: resource_content_id
    ).first_or_initialize

    info.short_text = draft_short_text.to_s.strip
    info.text = draft_text.to_s.strip
    info.language_id = resource_content.language_id
    info.language_name = resource_content.language_name&.downcase

    attribute_versions_to(user) do
      info.save(validate: false)
    end

    resource_content.touch
    update_columns(imported: true)

    info
  end

  # Plain text, one block (paragraph, heading, list item) per line, for diffs
  def self.text_lines(html)
    text = html.to_s.gsub(%r{</(p|h[1-6]|li|div|blockquote|tr)>|<br\s*/?>}i, "\n")
    Rails::HTML5::FullSanitizer.new.sanitize(text).lines.map(&:squish).compact_blank.join("\n")
  end

  def short_text_edited?
    current_short_text.to_s.strip != draft_short_text.to_s.strip
  end

  def text_edited?
    squish_tags(current_text) != squish_tags(draft_text)
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

  # The editor puts each block on its own line, that alone isn't a change
  def matches_current?
    !short_text_edited? && !text_edited?
  end

  private

  def squish_tags(html)
    html.to_s.gsub(/>\s+</, '><').strip
  end

  # Moved to another surah in the CMS, compare against that surah's info.
  def refresh_current_text
    info = original_surah_info
    self.current_text = info&.text
    self.current_short_text = info&.short_text
  end
end
