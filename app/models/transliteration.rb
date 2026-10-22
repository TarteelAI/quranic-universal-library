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
# Ayah by ayah transliteration. Word by word transliterations are in WordTransliteration.
class Transliteration < QuranApiRecord
  include StripWhitespaces
  include Resourceable

  has_paper_trail on: :update, ignore: [:created_at, :updated_at]

  belongs_to :verse
  belongs_to :language

  before_save :set_verse_fields, if: :verse_id_changed?

  # Suggestions go through Draft::Translation, same as ayah translations.
  # Draft::Translation#import! writes them back here for transliteration resources.
  def draft_translations
    Draft::Translation.where(resource_content_id: resource_content_id, verse_id: verse_id)
  end

  def build_draft
    Draft::Translation.new(
      current_text: text,
      draft_text: text.to_s, # blank for a new transliteration, draft_text= can't format nil
      verse: verse,
      resource_content_id: resource_content_id
    )
  end

  def save_suggestions(params, user)
    draft = Draft::Translation.new(params)
    draft.resource_content_id = resource_content_id
    draft.current_text = text
    draft.text_matched = draft.draft_text == text
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
