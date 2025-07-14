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
class AyahTheme < QuranApiRecord
  belongs_to :chapter
  belongs_to :verse_from, class_name: 'Verse', foreign_key: 'verse_id_from'
  belongs_to :verse_to, class_name: 'Verse', foreign_key: 'verse_id_from'

  def self.for_verse(verse)
    AyahTheme
      .where(":ayah >= verse_id_from AND :ayah <= verse_id_to ", ayah: verse.id)
      .first
  end

  def ayahs
    Verse.where(id: verse_id_from..verse_id_to).order('verse_index ASC')
  end
end

