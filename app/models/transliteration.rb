# == Schema Information
#
# Table name: transliterations
#
#  id                  :integer          not null, primary key
#  language_name       :string
#  text                :text
#  verse_key           :string
#  verse_number        :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  chapter_id          :integer
#  language_id         :integer
#  resource_content_id :integer
#  verse_id            :integer          not null
#
# Indexes
#
#  index_transliterations_on_language_id                       (language_id)
#  index_transliterations_on_resource_content_id               (resource_content_id)
#  index_transliterations_on_resource_content_id_and_verse_id  (resource_content_id,verse_id) UNIQUE
#  index_transliterations_on_verse_id                          (verse_id)
#
class Transliteration < QuranApiRecord
  include StripWhitespaces
  include Resourceable

  has_paper_trail on: :update, ignore: [:created_at, :updated_at]

  belongs_to :verse
  belongs_to :language

  before_save :set_verse_fields, if: :verse_id_changed?

  def drafts
    Draft::Transliteration.where(resource_content_id: resource_content_id, verse_id: verse_id)
  end

  def build_draft
    Draft::Transliteration.new(
      current_text: text,
      draft_text: text,
      verse: verse,
      resource_content_id: resource_content_id
    )
  end

  # Tags that mark tajweed and letter details, nothing else is allowed
  ALLOWED_TAGS = %w[b strong i em u s small].freeze

  # Messages for tags that aren't allowed, or that have attributes
  def self.tag_errors(text)
    tags = text.to_s.scan(%r{<\s*/?\s*([a-zA-Z][\w-]*)([^>]*)>})
    names = tags.map { |name, _| name.downcase }.uniq - ALLOWED_TAGS
    errors = names.map { |name| "<#{name}> isn't allowed, only #{ALLOWED_TAGS.map { |t| "<#{t}>" }.join(', ')}" }
    errors << 'Tags have no attributes, write <b> instead of <b class="...">' if tags.any? { |_, attrs| attrs.strip.delete('/').present? }
    errors
  end

  def self.sanitize_tags(text)
    Rails::HTML5::SafeListSanitizer.new.sanitize(text.to_s, tags: ALLOWED_TAGS, attributes: [])
  end

  # Returns false and sets errors when the text is blank or has tags that aren't allowed
  def save_suggestions(params, user)
    errors.add(:base, 'Transliteration text is required') if params[:draft_text].blank?
    self.class.tag_errors(params[:draft_text]).each { |message| errors.add(:base, message) }
    return false if errors.any?

    draft = Draft::Transliteration.new(params)
    draft.resource_content_id = resource_content_id
    draft.current_text = text
    draft.text_matched = draft.draft_text.to_s.strip == text.to_s.strip
    draft.verse = verse
    draft.need_review = true
    draft.user = user
    draft.save(validate: false)
    draft
  end

  protected

  def set_verse_fields
    self.verse_key = verse.verse_key
    self.chapter_id = verse.chapter_id
    self.verse_number = verse.verse_number
  end
end
