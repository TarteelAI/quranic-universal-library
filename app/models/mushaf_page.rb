# == Schema Information
#
# Table name: mushaf_pages
#
#  id             :bigint           not null, primary key
#  lines_count    :integer
#  page_number    :integer
#  verse_mapping  :json
#  verses_count   :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  first_verse_id :integer
#  first_word_id  :integer
#  last_verse_id  :integer
#  last_word_id   :integer
#  mushaf_id      :integer
#
# Indexes
#
#  index_mushaf_pages_on_lines_count  (lines_count)
#  index_mushaf_pages_on_mushaf_id    (mushaf_id)
#  index_mushaf_pages_on_page_number  (page_number)
#

class MushafPage < QuranApiRecord
  include NavigationSearchable
  belongs_to :mushaf

  belongs_to :first_verse, class_name: 'Verse'
  belongs_to :last_verse, class_name: 'Verse'

  belongs_to :first_word, class_name: 'Word'
  belongs_to :last_word, class_name: 'Word'

  has_many :verses, foreign_key: :page_number
  has_many :chapters, through: :verses

  def words
    MushafWord.where(
      mushaf_id: mushaf_id,
      page_number: page_number
    ).order('position_in_page ASC, position_in_line ASC')
  end

  def update_lines_count
    words = MushafWord.unscoped.where(
      mushaf_id: mushaf_id,
      page_number: page_number
    )

    line_alignments = MushafLineAlignment
                        .where(
                          mushaf_id: mushaf_id,
                          page_number: page_number
                        )
                        .order('line_number DESC')

    word_lines = words.pluck(:line_number).uniq
    word_lines += line_alignments.pluck(:line_number)

    update_column :lines_count, word_lines.uniq.size
  end

  def lines
    grouped_by_line = words.group_by(&:line_number).sort_by { |line_number, _| line_number }

    grouped_by_line.map do |line_number, words|
      line_alignment = MushafLineAlignment.where(
        mushaf_id: mushaf_id,
        page_number: page_number,
        line_number: line_number
      ).first

      {
        line: line_number,
        center_aligned: line_alignment&.is_center_aligned?,
        text: words.map(&:text).join(' ')
      }
    end
  end

  def first_ayah_key
    Utils::Quran.get_ayah_key_from_id(first_verse_id)
  end

  def last_ayah_key
    Utils::Quran.get_ayah_key_from_id(last_verse_id)
  end

  def fix_verse_mapping
    # TODO: add verse_mapping_with_range column
    page_verses = Verse.order("verse_index ASC").where("verse_index >= #{first_verse_id} AND verse_index <= #{last_verse_id}")
    map = {}

    page_verses.each do |verse|
      if map[verse.chapter_id]
        next
      end

      chapter_verses = page_verses.where(chapter_id: verse.chapter_id)
      map[verse.chapter_id] = {
        range: "#{chapter_verses.first.verse_number}-#{chapter_verses.last.verse_number}",
        count: chapter_verses.last.verse_number - chapter_verses.first.verse_number + 1
      }
    end

    update_columns(verses_count: verses.size, verse_mapping: map)
  end
end
