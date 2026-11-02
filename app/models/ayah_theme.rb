# == Schema Information
#
# Table name: ayah_themes
#
#  id                :bigint           not null, primary key
#  keywords          :jsonb
#  theme             :string
#  verse_id_from     :integer
#  verse_id_to       :integer
#  verse_key_from    :string
#  verse_key_to      :string
#  verse_number_from :integer
#  verse_number_to   :integer
#  verses_count      :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  book_id           :integer
#  chapter_id        :integer
#
# Indexes
#
#  index_ayah_themes_on_chapter_id         (chapter_id)
#  index_ayah_themes_on_verse_id_from      (verse_id_from)
#  index_ayah_themes_on_verse_id_to        (verse_id_to)
#  index_ayah_themes_on_verse_number_from  (verse_number_from)
#  index_ayah_themes_on_verse_number_to    (verse_number_to)
#
class AyahTheme < QulQuranRecord
  has_paper_trail on: %i[update destroy], ignore: %i[created_at updated_at]

  belongs_to :chapter
  belongs_to :verse_from, class_name: 'Verse', foreign_key: 'verse_id_from'
  belongs_to :verse_to, class_name: 'Verse', foreign_key: 'verse_id_to'

  def self.for_verse(verse)
    AyahTheme
      .where(":ayah >= verse_id_from AND :ayah <= verse_id_to ", ayah: verse.id)
      .first
  end

  def ayahs
    Verse.where(id: verse_id_from..verse_id_to).order('verse_index ASC')
  end

  def range_label
    verse_key_from == verse_key_to ? verse_key_from : "#{verse_key_from} - #{verse_key_to}"
  end

  # Other themes of the surah that share an ayah with this one
  def overlapping_themes
    AyahTheme
      .where(chapter_id: chapter_id)
      .where.not(id: id)
      .where('verse_id_from <= :to AND verse_id_to >= :from', from: verse_id_from, to: verse_id_to)
  end

  def set_range(from_id, to_id)
    from = Verse.find(from_id)
    to = Verse.find(to_id)

    self.verse_id_from = from.id
    self.verse_id_to = to.id
    self.verse_number_from = from.verse_number
    self.verse_number_to = to.verse_number
    self.verse_key_from = from.verse_key
    self.verse_key_to = to.verse_key
    self.verses_count = to.verse_number - from.verse_number + 1
  end

  # Saves a user's fix as a draft, it goes live once approved, see Draft::AyahTheme.
  # params: theme, keywords ("Supplication, Allah"), verse_number_from, verse_number_to, comment
  def save_suggestions(params, user)
    from = chapter.verses.find_by(verse_number: params[:verse_number_from].to_i)
    to = chapter.verses.find_by(verse_number: params[:verse_number_to].to_i)

    errors.add(:base, 'Theme is required') if params[:theme].blank?
    errors.add(:base, 'Pick the first and last ayah of the theme') if from.nil? || to.nil?
    errors.add(:base, 'The first ayah must come before the last ayah') if from && to && from.verse_number > to.verse_number
    return false if errors.any?

    splits = AyahTheme.where(chapter_id: chapter_id).where.not(id: id)
                      .where('verse_id_from < :from AND verse_id_to > :to', from: from.id, to: to.id)
    errors.add(:base, "This range is inside the theme for #{splits.first.range_label}, it would split it in two") if splits.exists?

    draft = Draft::AyahTheme.new(
      ayah_theme_id: id,
      chapter_id: chapter_id,
      user: user,
      comment: params[:comment].to_s.strip.presence,
      current_theme: theme,
      draft_theme: params[:theme].to_s.strip,
      current_keywords: Array(keywords),
      draft_keywords: params[:keywords].to_s.split(',').map(&:strip).compact_blank,
      current_verse_id_from: verse_id_from,
      current_verse_id_to: verse_id_to,
      draft_verse_id_from: from.id,
      draft_verse_id_to: to.id
    )
    errors.add(:base, 'Nothing was changed') if errors.empty? && draft.matches_current?
    return false if errors.any?

    draft.save(validate: false)
  end
end
