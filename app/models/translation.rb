# == Schema Information
#
# Table name: translations
#
#  id                  :integer          not null, primary key
#  footnotes_count     :integer          default(0)
#  hizb_number         :integer
#  juz_number          :integer
#  language_name       :string
#  manzil_number       :integer
#  page_number         :integer
#  priority            :integer
#  resource_name       :string
#  rub_el_hizb_number  :integer
#  ruku_number         :integer
#  surah_ruku_number   :integer
#  text                :text
#  verse_key           :string
#  verse_number        :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  chapter_id          :integer
#  language_id         :integer
#  resource_content_id :integer
#  verse_id            :integer
#
# Indexes
#
#  index_translations_on_chapter_id                   (chapter_id)
#  index_translations_on_chapter_id_and_verse_number  (chapter_id,verse_number)
#  index_translations_on_footnotes_count              (footnotes_count)
#  index_translations_on_hizb_number                  (hizb_number)
#  index_translations_on_juz_number                   (juz_number)
#  index_translations_on_language_id                  (language_id)
#  index_translations_on_manzil_number                (manzil_number)
#  index_translations_on_page_number                  (page_number)
#  index_translations_on_priority                     (priority)
#  index_translations_on_resource_content_id          (resource_content_id)
#  index_translations_on_rub_el_hizb_number           (rub_el_hizb_number)
#  index_translations_on_ruku_number                  (ruku_number)
#  index_translations_on_verse_id                     (verse_id)
#  index_translations_on_verse_key                    (verse_key)
#

class Translation < QuranApiRecord
  include StripWhitespaces
  include Resourceable

  has_paper_trail on: :update, ignore: [:created_at, :updated_at]

  belongs_to :verse
  belongs_to :language
  has_many :foot_notes
  has_many :draft_translations, class_name: 'Draft::Translation'

  after_update :touch_resource_content_timestamp

  scope :with_footnotes, -> { where "footnotes_count > 0" }
  scope :without_footnotes, -> { where "footnotes_count = 0" }

  def self.text_search(query)
    where "translations.text ilike ?", "%#{query}%"
  end

  def build_draft
    draft = draft_translations.build
    draft.current_text = text
    draft.draft_text = text
    draft.verse = verse
    draft.resource_content_id = resource_content_id

    foot_notes.each do |foot_note|
      draft.foot_notes.build(
        current_text: foot_note.text,
        draft_text: foot_note.text,
        resource_content_id: resource_content_id,
        foot_note: foot_note
      )
    end

    draft
  end

  def save_suggestions(params, user)
    draft_translation = Draft::Translation.new(params)
    draft_translation.resource_content_id = resource_content_id
    draft_translation.current_text = text
    draft_translation.text_matched = draft_translation.draft_text == text
    draft_translation.verse = verse
    draft_translation.need_review = true
    draft_translation.user = user
    draft_translation.save(validate: false)
    draft_translation
  end

  def update_footnote_count
    update_column :footnotes_count, foot_notes.count
  end

  protected

  def touch_resource_content_timestamp
    get_resource_content.touch
  end

  def attributes_to_strip
    [:language_name, :text, :verse_key]
  end
end
