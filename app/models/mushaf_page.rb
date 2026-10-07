# == Schema Information
#
# Table name: mushaf_pages
#
#  id             :integer          not null, primary key
#  page_number    :integer
#  verse_mapping  :json
#  first_verse_id :integer
#  last_verse_id  :integer
#  verses_count   :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  mushaf_id      :integer
#  first_word_id  :integer
#  last_word_id   :integer
#  lines_count    :integer
#
# Indexes
#
#  index_mushaf_pages_on_lines_count  (lines_count)
#  index_mushaf_pages_on_mushaf_id    (mushaf_id)
#  index_mushaf_pages_on_page_number  (page_number)
#

class MushafPage < QuranApiRecord
  include NavigationSearchable
  belongs_to :mushaf, optional: true

  belongs_to :first_verse, class_name: 'Verse', optional: true
  belongs_to :last_verse, class_name: 'Verse', optional: true
  belongs_to :first_ayah, class_name: 'NumberedAyah', optional: true # the page's ayah range in the mushaf's numbering (P5.2)
  belongs_to :last_ayah, class_name: 'NumberedAyah', optional: true

  belongs_to :first_word, class_name: 'Word', optional: true
  belongs_to :last_word, class_name: 'Word', optional: true

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

  # The page's ayah range named in the mushaf's own numbering (P5.5); the Kufi
  # key from the verse id until the numbering columns are filled.
  def first_ayah_key
    first_ayah&.ayah_key || Utils::Quran.get_ayah_key_from_id(first_verse_id)
  end

  def last_ayah_key
    last_ayah&.ayah_key || Utils::Quran.get_ayah_key_from_id(last_verse_id)
  end

  # The one shape of verse_mapping every writer uses since P5.2:
  #   { chapter_id => { range: "from-to", count: n } }
  # (older rows may still hold the plain "from-to" string per chapter).
  def self.build_verse_mapping(first_verse_id, last_verse_id)
    page_verses = Verse.order(:verse_index).where(verse_index: first_verse_id..last_verse_id)
    page_verses.group_by(&:chapter_id).to_h do |chapter_id, chapter_verses|
      [chapter_id, { range: "#{chapter_verses.first.verse_number}-#{chapter_verses.last.verse_number}",
                     count: chapter_verses.last.verse_number - chapter_verses.first.verse_number + 1 }]
    end
  end

  def fix_verse_mapping
    map = self.class.build_verse_mapping(first_verse_id, last_verse_id)
    update_columns(verses_count: verses.size, verse_mapping: map)
  end
end
