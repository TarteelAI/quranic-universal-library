# == Schema Information
#
# Table name: tafsirs
#
#  id                   :integer          not null, primary key
#  archived             :boolean          default(FALSE)
#  group_verse_key_from :string
#  group_verse_key_to   :string
#  group_verses_count   :integer
#  hizb_number          :integer
#  juz_number           :integer
#  language_name        :string
#  manzil_number        :integer
#  page_number          :integer
#  resource_name        :string
#  rub_el_hizb_number   :integer
#  ruku_number          :integer
#  surah_ruku_number    :integer
#  text                 :text
#  verse_key            :string
#  verse_number         :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  chapter_id           :integer
#  end_verse_id         :integer
#  group_tafsir_id      :integer
#  language_id          :integer
#  resource_content_id  :integer
#  start_verse_id       :integer
#  verse_id             :integer
#
# Indexes
#
#  index_tafsirs_on_chapter_id                   (chapter_id)
#  index_tafsirs_on_chapter_id_and_verse_number  (chapter_id,verse_number)
#  index_tafsirs_on_end_verse_id                 (end_verse_id)
#  index_tafsirs_on_hizb_number                  (hizb_number)
#  index_tafsirs_on_juz_number                   (juz_number)
#  index_tafsirs_on_language_id                  (language_id)
#  index_tafsirs_on_manzil_number                (manzil_number)
#  index_tafsirs_on_page_number                  (page_number)
#  index_tafsirs_on_resource_content_id          (resource_content_id)
#  index_tafsirs_on_rub_el_hizb_number           (rub_el_hizb_number)
#  index_tafsirs_on_ruku_number                  (ruku_number)
#  index_tafsirs_on_start_verse_id               (start_verse_id)
#  index_tafsirs_on_verse_id                     (verse_id)
#  index_tafsirs_on_verse_key                    (verse_key)
#

class Tafsir < QuranApiRecord
  has_paper_trail on: :update, ignore: [:created_at, :updated_at]
  include Resourceable

  belongs_to :verse
  belongs_to :chapter
  belongs_to :language

  # Works for a new tafsir too, to add tafsir for ayahs that have none.
  # Returns false and sets errors when the range or text is invalid.
  def save_suggestions(params, user)
    range_change = range_change_for(params[:start_verse_id], params[:end_verse_id])
    range_change.errors.each { |message| errors.add(:base, message) }
    errors.add(:base, 'Tafsir text is required') if params[:text].blank?
    return false if errors.any?

    draft_tafsir = Draft::Tafsir.new(tafsir_id: id)
    grouping_ayah = Verse.where("id >= ? AND id <= ?", params[:start_verse_id], params[:end_verse_id]).order('verse_index asc')

    draft_tafsir.resource_content_id = resource_content_id
    draft_tafsir.current_text = text
    draft_tafsir.draft_text = params[:text]
    draft_tafsir.text_matched = draft_tafsir.draft_text == text
    draft_tafsir.verse = verse || grouping_ayah.first
    draft_tafsir.verse_key = grouping_ayah.first.verse_key

    draft_tafsir.group_verse_key_from = grouping_ayah.first.verse_key
    draft_tafsir.group_verse_key_to = grouping_ayah.last.verse_key
    draft_tafsir.group_verses_count = grouping_ayah.size
    draft_tafsir.start_verse_id = grouping_ayah.first.id
    draft_tafsir.end_verse_id = grouping_ayah.last.id
    draft_tafsir.group_tafsir_id = grouping_ayah.first.id
    draft_tafsir.need_review = true
    draft_tafsir.user = user
    draft_tafsir.save(validate: false)
    draft_tafsir
  end

  def range_change_for(start_verse_id, end_verse_id)
    Draft::TafsirRangeChange.new(
      resource_content_id: resource_content_id,
      tafsir: self,
      start_verse_id: start_verse_id,
      end_verse_id: end_verse_id
    )
  end

  # "Surah Al-Fatihah, ayah 1", "Surah Al-Baqarah, ayahs 1 to 5" or "Surah Al-Isra 110 to Surah Al-Kahf 1"
  def ayah_range_label
    from_surah, from_ayah = group_verse_key_from.to_s.split(':').map(&:to_i)
    to_surah, to_ayah = group_verse_key_to.to_s.split(':').map(&:to_i)
    names = Chapter.where(chapter_number: [from_surah, to_surah].uniq).pluck(:chapter_number, :name_simple).to_h

    if from_surah != to_surah
      "Surah #{names[from_surah]} #{from_ayah} to Surah #{names[to_surah]} #{to_ayah}"
    elsif from_ayah == to_ayah
      "Surah #{names[from_surah]}, ayah #{from_ayah}"
    else
      "Surah #{names[from_surah]}, ayahs #{from_ayah} to #{to_ayah}"
    end
  end

  def ayah_group_info
    "#{group_verse_key_from} - #{group_verse_key_to}"
  end

  def ayah_group_list
    ayahs.pluck(:verse_key)
  end

  def ayahs
    Verse.where(id: start_verse_id..end_verse_id).order('verse_index ASC')
  end

  def self.text_search(query)
    where "tafsirs.text ilike ?", "%#{query}%"
  end

  def self.for_verse(verse, resource)
    Tafsir
      .where(resource_content_id: resource.id)
      .where(":ayah >= start_verse_id AND :ayah <= end_verse_id ", ayah: verse.id)
      .first
  end

  def start_verse_id=(val)
    super(val)
    self.group_verse_key_from = Verse.find(val).verse_key
  end

  def end_verse_id=(val)
    super(val)
    self.group_verse_key_to = Verse.find(val).verse_key
  end
end
