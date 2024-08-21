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
#  need_review          :boolean
#  reviewed             :boolean
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
#  index_draft_tafsirs_on_user_id       (user_id)
#  index_draft_tafsirs_on_verse_id      (verse_id)
#  index_draft_tafsirs_on_verse_key     (verse_key)
#
class Draft::Tafsir < ApplicationRecord
  belongs_to :resource_content
  belongs_to :verse
  belongs_to :group_tafsir, class_name: 'Verse', optional: true #TODO: rename to group_verse
  belongs_to :user, optional: true

  def import!
    language = resource_content.language
    tafsir = Tafsir.where(
      verse_id: verse_id,
      resource_content_id: resource_content.id
    ).first_or_initialize

    tafsir.text = draft_text.strip
    tafsir.language_id = language.id
    tafsir.language_name = language.name.downcase
    tafsir.resource_name = resource_content.name if tafsir.resource_name.blank?

    tafsir.verse_key = verse.verse_key
    tafsir.chapter_id = verse.chapter_id
    tafsir.verse_number = verse.verse_number
    tafsir.juz_number = verse.juz_number
    tafsir.hizb_number = verse.hizb_number
    tafsir.rub_el_hizb_number = verse.rub_el_hizb_number
    tafsir.ruku_number = verse.ruku_number
    tafsir.surah_ruku_number = verse.surah_ruku_number
    tafsir.manzil_number = verse.manzil_number
    tafsir.page_number = verse.page_number

    tafsir.group_verse_key_from = group_verse_key_from
    tafsir.group_verse_key_to = group_verse_key_to
    tafsir.group_verses_count = Verse.where("id >= ? AND id <= ?", start_verse_id, end_verse_id).count
    tafsir.group_tafsir_id = group_tafsir_id
    tafsir.start_verse_id = start_verse_id
    tafsir.end_verse_id = end_verse_id

    tafsir.save(validate: false)
    update_columns(reviewed: true, imported: true)
    tafsir
  end

  def ayah_group_info
    "#{group_verse_key_from} - #{group_verse_key_to}"
  end

  def ayah_group_list
    Verse.where(id: start_verse_id..end_verse_id).order('verse_index ASC').pluck(:verse_key)
  end

  def ayah_group_info
    "#{group_verse_key_from} - #{group_verse_key_to}"
  end

  def original_tafsir
    Tafsir.where(verse_id: verse_id, resource_content_id: resource_content_id).first
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

  def self.new_tafsirs
    ids = where(imported: false).select('DISTINCT resource_content_id, imported')

    ResourceContent.where(id: ids.map(&:resource_content_id))
  end

  def self.imported
    ids = where(imported: true).select('DISTINCT resource_content_id, imported')

    ResourceContent.where(id: ids.map(&:resource_content_id))
  end

  def self.for_verse(verse, resource)
    where(resource_content_id: resource.id)
      .where(":ayah >= start_verse_id AND :ayah <= end_verse_id ", ayah: verse.id)
      .first
  end

  def update_ayah_grouping
    group = ayah_group_list
    tafsir = Draft::Tafsir.for_verse(verse, resource_content)

    cols = {
      group_verses_count: group.size,
      reviewed: true
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
          group_tafsir_id: verse_id,
          group_verse_key_from: group_verse_key_from,
          group_verse_key_to: group_verse_key_to,
          start_verse_id: start_verse_id,
          end_verse_id: end_verse_id,
          reviewed: true
        )
    end
  end
end
