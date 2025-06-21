# == Schema Information
#
# Table name: draft_word_translations
#
#  id                    :bigint           not null, primary key
#  current_group_text    :string
#  current_text          :string
#  draft_group_text      :string
#  draft_text            :string
#  imported              :boolean          default(FALSE)
#  location              :string
#  meta_data             :jsonb
#  need_review           :boolean          default(TRUE)
#  text_matched          :boolean          default(FALSE)
#  word_group_size       :integer          default(1)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  current_group_word_id :integer
#  draft_group_word_id   :integer
#  language_id           :integer
#  resource_content_id   :integer
#  user_id               :integer
#  verse_id              :integer
#  word_id               :integer
#  word_translation_id   :integer
#
# Indexes
#
#  index_draft_word_translations_on_current_group_word_id  (current_group_word_id)
#  index_draft_word_translations_on_draft_group_word_id    (draft_group_word_id)
#  index_draft_word_translations_on_imported               (imported)
#  index_draft_word_translations_on_language_id            (language_id)
#  index_draft_word_translations_on_location               (location)
#  index_draft_word_translations_on_need_review            (need_review)
#  index_draft_word_translations_on_resource_content_id    (resource_content_id)
#  index_draft_word_translations_on_text_matched           (text_matched)
#  index_draft_word_translations_on_verse_id               (verse_id)
#  index_draft_word_translations_on_word_group_size        (word_group_size)
#  index_draft_word_translations_on_word_id                (word_id)
#  index_draft_word_translations_on_word_translation_id    (word_translation_id)
#
class Draft::WordTranslation < ApplicationRecord
  belongs_to :verse
  belongs_to :word
  belongs_to :language
  belongs_to :resource_content
  belongs_to :word_translation, optional: true

  def self.new_translations
    ids = select('DISTINCT resource_content_id, imported')

    ResourceContent.where(id: ids.map(&:resource_content_id))
  end

  def self.imported_translations
    ids = where(imported: true).select('DISTINCT resource_content_id, imported')

    ResourceContent.where(id: ids.map(&:resource_content_id))
  end

  def original_translation
    WordTranslation.where(word: word, resource_content_id: resource_content_id).first
  end

  def next_word_translation
    if next_word = word.next_word
      next_word = next_word.next_word if next_word.ayah_mark?
      Draft::WordTranslation
        .where(resource_content_id: resource_content_id)
        .where(word: next_word)
        .first
    end
  end

  def previous_word_translation
    if previous_word = word.previous_word
      previous_word = previous_word.previous_word if previous_word.ayah_mark?

      Draft::WordTranslation
        .where(resource_content_id: resource_content_id)
        .where(word: previous_word)
        .first
    end
  end
end
