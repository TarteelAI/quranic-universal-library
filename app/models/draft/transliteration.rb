# == Schema Information
#
# Table name: draft_transliterations
#
#  id                  :bigint           not null, primary key
#  current_text        :text
#  draft_text          :text
#  imported            :boolean          default(FALSE)
#  meta_data           :jsonb
#  need_review         :boolean          default(TRUE)
#  text_matched        :boolean          default(FALSE)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  resource_content_id :integer
#  user_id             :integer
#  verse_id            :integer
#
# Indexes
#
#  index_draft_transliterations_on_imported             (imported)
#  index_draft_transliterations_on_need_review          (need_review)
#  index_draft_transliterations_on_resource_content_id  (resource_content_id)
#  index_draft_transliterations_on_text_matched         (text_matched)
#  index_draft_transliterations_on_verse_id             (verse_id)
#
class Draft::Transliteration < ApplicationRecord
  include PaperTrailAttribution
  include DraftResourceStats

  belongs_to :resource_content
  belongs_to :verse
  belongs_to :user, optional: true

  def original_transliteration
    ::Transliteration.find_by(verse_id: verse_id, resource_content_id: resource_content_id)
  end

  def previous_ayah_draft
    Draft::Transliteration
      .where(resource_content_id: resource_content_id)
      .where('verse_id < ?', verse_id)
      .order(verse_id: :desc)
      .first
  end

  def next_ayah_draft
    Draft::Transliteration
      .where(resource_content_id: resource_content_id)
      .where('verse_id > ?', verse_id)
      .order(:verse_id)
      .first
  end

  def import!
    transliteration = ::Transliteration.where(
      verse_id: verse_id,
      resource_content_id: resource_content_id
    ).first_or_initialize

    transliteration.text = draft_text.strip
    transliteration.language_id = resource_content.language_id
    transliteration.language_name = resource_content.language_name

    attribute_versions_to(user) do
      transliteration.save(validate: false)
    end

    resource_content.touch
    update_columns(imported: true)

    transliteration
  end
end
