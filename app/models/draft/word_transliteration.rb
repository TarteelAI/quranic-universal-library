# == Schema Information
#
# Table name: draft_word_transliterations
#
#  id                  :bigint           not null, primary key
#  current_text        :string
#  draft_text          :string
#  imported            :boolean          default(FALSE)
#  location            :string
#  meta_data           :jsonb
#  need_review         :boolean          default(TRUE)
#  text_matched        :boolean          default(FALSE)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  resource_content_id :integer
#  user_id             :integer
#  verse_id            :integer
#  word_id             :integer
#
# Indexes
#
#  index_draft_word_transliterations_on_imported             (imported)
#  index_draft_word_transliterations_on_location             (location)
#  index_draft_word_transliterations_on_need_review          (need_review)
#  index_draft_word_transliterations_on_resource_content_id  (resource_content_id)
#  index_draft_word_transliterations_on_text_matched         (text_matched)
#  index_draft_word_transliterations_on_verse_id             (verse_id)
#  index_draft_word_transliterations_on_word_id              (word_id)
#
class Draft::WordTransliteration < ApplicationRecord
  include PaperTrailAttribution
  include DraftResourceStats

  belongs_to :resource_content

  belongs_to :verse
  belongs_to :word
  belongs_to :user, optional: true

  # Fixes suggested by users that aren't approved yet
  scope :pending_contributions, -> { where.not(user_id: nil).where(imported: false) }

  before_save :set_word_fields, if: :word_id_changed?

  def original_transliteration
    ::WordTransliteration.find_by(word_id: word_id, resource_content_id: resource_content_id)
  end

  def previous_word_draft
    Draft::WordTransliteration
      .where(resource_content_id: resource_content_id)
      .where('word_id < ?', word_id)
      .order(word_id: :desc)
      .first
  end

  def next_word_draft
    Draft::WordTransliteration
      .where(resource_content_id: resource_content_id)
      .where('word_id > ?', word_id)
      .order(:word_id)
      .first
  end

  def import!
    word_transliteration = ::WordTransliteration.where(
      word_id: word_id,
      resource_content_id: resource_content_id
    ).first_or_initialize

    word_transliteration.text = draft_text.strip
    word_transliteration.language_id = resource_content.language_id
    word_transliteration.language_name = resource_content.language_name&.downcase

    attribute_versions_to(user) do
      word_transliteration.save(validate: false)
    end

    resource_content.touch
    update_columns(imported: true)

    word_transliteration
  end

  private

  # Moved to another word in the CMS, keep verse and location in sync and
  # compare against that word's transliteration.
  def set_word_fields
    self.verse_id = word.verse_id
    self.location = word.location
    self.current_text = original_transliteration&.text
    self.text_matched = current_text.to_s.strip == draft_text.to_s.strip
  end
end
