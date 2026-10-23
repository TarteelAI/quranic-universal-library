# == Schema Information
#
# Table name: chapter_infos
#
#  id                  :integer          not null, primary key
#  language_name       :string
#  short_text          :text
#  source              :string
#  text                :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  chapter_id          :integer
#  language_id         :integer
#  resource_content_id :integer
#
# Indexes
#
#  index_chapter_infos_on_chapter_id           (chapter_id)
#  index_chapter_infos_on_language_id          (language_id)
#  index_chapter_infos_on_resource_content_id  (resource_content_id)
#
class ChapterInfo < QuranApiRecord
  has_paper_trail on: :update, ignore: [:created_at, :updated_at]

  belongs_to :resource_content, optional: true
  belongs_to :chapter
  belongs_to :language

  def surah_name
    chapter.name_simple
  end

  def previous_surah_info
    ChapterInfo
      .where(
        resource_content_id: resource_content_id,
        chapter_id: chapter_id - 1
      )
      .first
  end

  def next_surah_info
    ChapterInfo
      .where(
        resource_content_id: resource_content_id,
        chapter_id: chapter_id + 1
      )
      .first
  end

  def drafts
    Draft::SurahInfo.where(resource_content_id: resource_content_id, chapter_id: chapter_id)
  end

  def build_draft
    Draft::SurahInfo.new(
      current_short_text: short_text,
      draft_short_text: short_text,
      current_text: text,
      draft_text: text,
      chapter: chapter,
      resource_content_id: resource_content_id
    )
  end

  # Returns false and sets errors when the text is blank
  def save_suggestions(params, user)
    errors.add(:base, 'Surah info text is required') if params[:draft_text].blank?
    return false if errors.any?

    draft = build_draft
    draft.assign_attributes(params)
    draft.text_matched = draft.matches_current?
    draft.need_review = true
    draft.user = user
    draft.save(validate: false)
    draft
  end
end
