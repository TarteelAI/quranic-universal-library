# == Schema Information
#
# Table name: draft_tafsirs
#
#  id                   :bigint           not null, primary key
#  comments             :string
#  current_text         :text
#  draft_text           :text
#  group_verse_key_from :string
#  group_verse_key_to   :string
#  group_verses_count   :integer
#  imported             :boolean          default(FALSE)
#  md5                  :string
#  meta_data            :jsonb
#  need_review          :boolean          default(FALSE)
#  reviewed             :boolean          default(FALSE)
#  text_matched         :boolean
#  verse_key            :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  end_verse_id         :integer
#  group_tafsir_id      :integer
#  resource_content_id  :integer
#  start_verse_id       :integer
#  tafsir_id            :integer
#  user_id              :integer
#  verse_id             :integer
#
# Indexes
#
#  index_draft_tafsirs_on_need_review   (need_review)
#  index_draft_tafsirs_on_tafsir_id     (tafsir_id)
#  index_draft_tafsirs_on_text_matched  (text_matched)
#  index_draft_tafsirs_on_verse_id      (verse_id)
#  index_draft_tafsirs_on_verse_key     (verse_key)
#
class Draft::Tafsir < ApplicationRecord
  include HasMetaData
  belongs_to :resource_content
  belongs_to :verse
  belongs_to :tafsir, optional: true, class_name: '::Tafsir'
  belongs_to :group_tafsir, class_name: 'Verse', optional: true # TODO: rename to group_verse
  belongs_to :user, optional: true
  belongs_to :start_verse, class_name: 'Verse'
  belongs_to :end_verse, class_name: 'Verse'

  scope :verse_key_cont, lambda { |ayah|
    ayah = Verse.find_by(verse_key: ayah) if ayah.is_a?(String)
    where(":ayah >= start_verse_id AND :ayah <= end_verse_id ", ayah: ayah.id)
  }
  scope :verse_key_eq, ->(ayah) { verse_key_cont(ayah) }
  scope :verse_key_start, ->(ayah) { where("start_verse_id = ?", Verse.find_by(verse_key: ayah)&.id) }
  scope :verse_key_end, ->(ayah) { where("end_verse_id = ?", Verse.find_by(verse_key: ayah)&.id) }

  def source_link
    if resource_content.sourced_from_tafsir_app?
      "https://tafsir.app/#{resource_content.tafsir_app_key}/#{verse.verse_key.sub(':', '/')}"
    elsif resource_content.sourced_from_quranenc?
      "https://quranenc.com/en/browse/#{resource_content.quran_enc_key}/#{verse.verse_key.sub(':', '/')}"
    end
  end

  def self.ransackable_scopes(auth_object = nil)
    %i[verse_key_cont verse_key_eq verse_key_start verse_key_end]
  end

  def import!
    language = resource_content.language
    group_verses = Verse.where("id >= ? AND id <= ?", start_verse_id, end_verse_id)
    primary_verse = verse

    if !group_verses.pluck(:id).include?(verse_id)
      primary_verse = group_verses.first
    end

    tafsir = Tafsir.where(
      verse_id: primary_verse.id,
      resource_content_id: resource_content.id
    ).first_or_initialize

    tafsir.verse = primary_verse
    tafsir.group_tafsir_id = primary_verse.id

    tafsir.text = draft_text.strip
    tafsir.language_id = language.id
    tafsir.language_name = language.name.downcase
    tafsir.resource_name = resource_content.name if tafsir.resource_name.blank?

    tafsir.verse_key = primary_verse.verse_key
    tafsir.chapter_id = primary_verse.chapter_id
    tafsir.verse_number = primary_verse.verse_number

    tafsir.juz_number = primary_verse.juz_number
    tafsir.hizb_number = primary_verse.hizb_number
    tafsir.rub_el_hizb_number = primary_verse.rub_el_hizb_number
    tafsir.ruku_number = primary_verse.ruku_number
    tafsir.surah_ruku_number = primary_verse.surah_ruku_number
    tafsir.manzil_number = primary_verse.manzil_number
    tafsir.page_number = primary_verse.page_number

    tafsir.group_verse_key_from = group_verse_key_from
    tafsir.group_verse_key_to = group_verse_key_to
    tafsir.group_verses_count = group_verses.count
    tafsir.start_verse_id = start_verse_id
    tafsir.end_verse_id = end_verse_id

    tafsir.save(validate: false)
    update_columns(reviewed: true, imported: true)

    if ayah_group_changed?
      split_ayah_grouping
    end

    tafsir
  end

  def clone_tafsir
    cloned = self.dup
    cloned.id = nil
    cloned.comments = "Cloned from #{id}"
    cloned.save(validate: false)

    cloned
  end

  def reprocess_text!
    sanitizer = Utils::TextSanitizer::TafsirSanitizer.new
    text =  sanitizer.sanitize(
      draft_text,
      resource_language: resource_content.language.iso_code
    ).html

    update_columns(draft_text: text)
  end

  def ayah_group_info
    "#{group_verse_key_from} - #{group_verse_key_to}"
  end

  def ayah_group_list
    Verse
      .where(
        id: start_verse_id..end_verse_id
      )
      .order('verse_index ASC')
      .pluck(:verse_key)
  end

  def ayah_group_info
    "#{group_verse_key_from} - #{group_verse_key_to}"
  end

  def original_tafsir
    Tafsir
      .where(verse_id: verse_id, resource_content_id: resource_content_id)
      .first || Tafsir.for_verse(verse, resource_content)
  end

  def main_group_tafsir
    Draft::Tafsir.for_verse(group_tafsir, resource_content)
  end

  def start_verse_id=(val)
    super(val)
    self.group_verse_key_from = Verse.find(val).verse_key
  end

  def end_verse_id=(val)
    super(val)
    self.group_verse_key_to = Verse.find(val).verse_key
  end

  def self.all_tafsirs
    counts = Draft::Tafsir
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

  def self.for_verse(verse, resource)
    where(resource_content_id: resource.id)
      .where(":ayah >= start_verse_id AND :ayah <= end_verse_id ", ayah: verse.id)
      .first
  end

  def update_ayah_grouping
    if ayah_group_changed?
      split_ayah_grouping
    end

    group = ayah_group_list
    tafsir = Draft::Tafsir.for_verse(verse, resource_content)
    group_verse_key = group.include?(verse.verse_key) ? verse.verse_key : group.first
    group_verse = Verse.find_by(verse_key: group_verse_key)

    cols = {
      group_verses_count: group.size,
      verse_id: group_verse.id,
      verse_key: group_verse.verse_key,
    }

    update_columns(cols)

    if tafsir == self && group.size > 1
      # Update grouping info for ayahs
      Draft::Tafsir
        .where(
          resource_content_id: resource_content_id,
          verse_key: group - [verse_key]
        )
        .update_all(
          group_verses_count: group.size,
          group_tafsir_id: group_verse.id,
          group_verse_key_from: group_verse_key_from,
          group_verse_key_to: group_verse_key_to,
          start_verse_id: start_verse_id,
          end_verse_id: end_verse_id,
          reviewed: true
        )
    end
  end

  def ayah_group_changed?
    end_verse_id_before_last_save != end_verse_id || start_verse_id_before_last_save != start_verse_id
  end

  def ayah_group_ids_before_update
    return [] if end_verse_id_before_last_save.blank? || start_verse_id_before_last_save.blank?

    (start_verse_id_before_last_save..end_verse_id_before_last_save).to_a
  end

  def ayah_group_ids
    (start_verse_id..end_verse_id).to_a
  end

  def split_ayah_grouping
    group_verse_ids = ayah_group_ids_before_update - ayah_group_ids
    return if group_verse_ids.blank?
    group_verses = Verse.unscoped.where(id: group_verse_ids).order('verse_index ASC')

    draft_tafsir = Draft::Tafsir
                     .where(
                       resource_content_id: resource_content_id,
                       verse_id: group_verses.map(&:id)
                     ).first

    if draft_tafsir.blank?
      draft_tafsir = Draft::Tafsir
                       .where(
                         resource_content_id: resource_content_id,
                         verse_id: group_verses.first.id
                       ).first_or_initialize
    end

    draft_tafsir.group_verses_count = group_verses.count
    draft_tafsir.group_tafsir_id = group_verses.first.id
    draft_tafsir.group_verse_key_from = group_verses.first.verse_key
    draft_tafsir.group_verse_key_to = group_verses.last.verse_key
    draft_tafsir.start_verse_id = group_verses.first.id
    draft_tafsir.end_verse_id = group_verses.last.id
    draft_tafsir.draft_text = draft_text_before_last_save
    draft_tafsir.current_text = current_text_before_last_save
    draft_tafsir.comments = "Auto splitted last group was #{group_verse_key_from_before_last_save} - #{group_verse_key_to_before_last_save}"
    draft_tafsir.need_review = true
    draft_tafsir.text_matched = false
    draft_tafsir.user = user

    draft_tafsir.save(validate: false)
  end

  def next_ayah_tafsir
    if end_verse_id < 6235
      Draft::Tafsir
        .where(resource_content_id: resource_content_id)
        .where("start_verse_id > ?", end_verse_id)
        .order('verse_id DESC')
        .last
    end
  end

  def previous_ayah_tafsir
    if start_verse_id > 1
      Draft::Tafsir
        .where(resource_content_id: resource_content_id)
        .where("end_verse_id < ?", start_verse_id)
        .order('verse_id DESC')
        .first
    end
  end
end
