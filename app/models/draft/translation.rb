# == Schema Information
#
# Table name: draft_translations
#
#  id                      :bigint           not null, primary key
#  current_footnotes_count :integer          default(0)
#  current_text            :text
#  draft_text              :text
#  footnotes_count         :integer          default(0)
#  imported                :boolean          default(FALSE)
#  meta_data               :jsonb
#  need_review             :boolean
#  text_matched            :boolean
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  resource_content_id     :integer
#  translation_id          :integer
#  user_id                 :integer
#  verse_id                :integer
#
# Indexes
#
#  index_draft_translations_on_footnotes_count      (footnotes_count)
#  index_draft_translations_on_need_review          (need_review)
#  index_draft_translations_on_resource_content_id  (resource_content_id)
#  index_draft_translations_on_text_matched         (text_matched)
#  index_draft_translations_on_translation_id       (translation_id)
#  index_draft_translations_on_verse_id             (verse_id)
#

class Draft::Translation < ApplicationRecord
  REGEXP_FOOTNOTE_ID = /foot_note=(?<id>\d+)/
  include HasMetaData

  belongs_to :resource_content
  belongs_to :verse
  belongs_to :user, optional: true
  belongs_to :translation, optional: true, class_name: '::Translation'

  has_many :foot_notes, class_name: 'Draft::FootNote', foreign_key: 'draft_translation_id'

  accepts_nested_attributes_for :foot_notes, allow_destroy: true

  scope :with_footnotes, -> { where "footnotes_count > 0" }
  scope :without_footnotes, -> { where "footnotes_count = 0" }
  scope :with_mismatch_footnote, -> { where "footnotes_count != current_footnotes_count" }

  def text=(val)
    self.draft_text = val
  end

  def draft_text=(val)
    formatted = Utils::TextFormatter.new(val).format
    super formatted
  end

  def next_ayah_translation
    if verse_id < 6235
      Draft::Translation
        .where(resource_content_id: resource_content_id)
        .where("verse_id > ?", verse_id)
        .order('verse_id DESC')
        .last
    end
  end

  def previous_ayah_translation
    if verse_id > 1
      Draft::Translation
        .where(resource_content_id: resource_content_id)
        .where("verse_id < ?", verse_id)
        .order('verse_id DESC')
        .first
    end
  end

  def import!
    language = resource_content.language
    translation = translation || Translation.where(
      verse_id: verse_id,
      resource_content_id: resource_content.id
    ).first_or_initialize

    translation.text = draft_text.strip
    translation.language_name = language.name
    translation.language_id = language.id

    translation.verse_key = verse.verse_key
    translation.chapter_id = verse.chapter_id
    translation.verse_number = verse.verse_number
    translation.juz_number = verse.juz_number
    translation.hizb_number = verse.hizb_number
    translation.rub_el_hizb_number = verse.rub_el_hizb_number
    translation.ruku_number = verse.ruku_number
    translation.surah_ruku_number = verse.surah_ruku_number
    translation.manzil_number = verse.manzil_number
    translation.page_number = verse.page_number

    translation.save(validate: false)

    foot_notes.each do |footnote|
      translation_footnote = translation.foot_notes.where(id: footnote.foot_note_id).first_or_initialize
      translation_footnote.text = footnote.draft_text
      translation_footnote.translation = translation
      translation_footnote.save(validate: false)
    end

    translation.get_resource_content.touch
    update_columns(imported: true)

    translation
  end

  def self.all_translations
    counts = Draft::Translation
               .group(:resource_content_id)
               .select("resource_content_id,
             COUNT(*) AS total_count,
             COUNT(CASE WHEN text_matched = true THEN 1 END) AS matched_count,
             COUNT(CASE WHEN text_matched = false THEN 1 END) AS not_matched_count,
             COUNT(CASE WHEN imported = true THEN 1 END) AS imported_count,
             COUNT(CASE WHEN imported = false THEN 1 END) AS not_imported_count,
             COUNT(CASE WHEN need_review = true THEN 1 END) AS need_review_count")

    resources = ResourceContent.where(id: counts.map(&:resource_content_id)).index_by(&:id)

    counts.map do |record|
      {
        resource: resources[record.resource_content_id],
        total_count: record.total_count.to_i,
        matched_count: record.matched_count.to_i,
        not_matched_count: record.not_matched_count.to_i,
        imported_count: record.imported_count.to_i,
        not_imported_count: record.not_imported_count.to_i,
        need_review_count: record.need_review_count.to_i
      }
    end
  end

  def original_translation
    Translation.where(verse_id: verse_id, resource_content_id: resource_content_id).first
  end

  def original_footnotes
    original_translation&.foot_notes || []
  end

  def original_footnotes_ids
    t = original_translation

    if t
      translation.text.scan(REGEXP_FOOTNOTE_ID).flatten.map(&:to_i)
    else
      []
    end
  end

  def footnotes_ids
    foot_notes.pluck :id
  end

  def original_footnote_text(foot_note_id)
    matched = original_footnotes.detect do |footnote|
      footnote.id == foot_note_id
    end

    matched || original_footnotes.first
  end

  def update_footnote_count
    update_column :footnotes_count, foot_notes.count
  end
end
