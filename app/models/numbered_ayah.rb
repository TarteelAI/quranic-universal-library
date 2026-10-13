# == Schema Information
#
# Table name: numbered_ayahs
#
#  id                  :bigint           not null, primary key
#  ayah_index          :integer
#  ayah_key            :string           not null
#  ayah_number         :integer          not null
#  counted             :boolean          default(TRUE), not null
#  relation            :string
#  words_count         :integer
#  chapter_id          :integer          not null
#  first_number        :integer
#  first_word_id       :integer
#  kufi_first_verse_id :integer
#  kufi_last_verse_id  :integer
#  last_number         :integer
#  last_word_id        :integer
#  numbering_id        :integer          not null
#
# Indexes
#
#  index_numbered_ayahs_on_first_word_id     (first_word_id)
#  index_numbered_ayahs_on_numbering_anchor  (numbering_id,kufi_first_verse_id)
#  index_numbered_ayahs_on_numbering_index   (numbering_id,ayah_index)
#  index_numbered_ayahs_on_numbering_key     (numbering_id,chapter_id,ayah_number) UNIQUE
#
# One ayah in one numbering: a range of shared words with the Kufi verse
# range it covers. A merged ayah spans two Kufi verses; split ayahs share one.
# ayah_number 0 with counted = false is a printed, unnumbered basmalah.
class NumberedAyah < QuranApiRecord
  RELATIONS = %w[same merged split shifted unnumbered].freeze

  belongs_to :numbering, class_name: 'AyahNumbering', inverse_of: :numbered_ayahs
  belongs_to :chapter
  belongs_to :first_word, class_name: 'Word', optional: true
  belongs_to :last_word, class_name: 'Word', optional: true
  belongs_to :kufi_first_verse, class_name: 'Verse', optional: true
  belongs_to :kufi_last_verse, class_name: 'Verse', optional: true

  validates :ayah_key, presence: true
  validates :relation, inclusion: { in: RELATIONS }, allow_nil: true

  scope :counted, -> { where(counted: true) }
  scope :in_order, -> { order(:chapter_id, :ayah_number) }

  # The Kufi verses this ayah covers (one for same/split, two for merged).
  # the number of words the ayah has, like Verse#words_count (P7.3 segment validation)
  def words_count
    self[:words_count] || words.count
  end

  def kufi_verses
    return Verse.none unless kufi_first_verse_id

    Verse.where(id: kufi_first_verse_id..kufi_last_verse_id).order(:id)
  end

  # The shared words of this ayah in order (all riwayat; filter per script).
  # Selected by shared number, not by id: word ids are not in text order.
  def words
    return Word.none unless first_number

    Word.unscoped.where(char_type_name: 'word')
        .where('number BETWEEN :a AND :b OR number_last BETWEEN :a AND :b', a: first_number, b: last_number)
        .order(:verse_id, :position, :sub_position)
  end

  # The ayah text in a script: the ayah_texts cache, else the joined forms of
  # its words in that script (word_texts for row-backed, column otherwise).
  def text_for(script)
    return nil if script.nil?

    cached = AyahText.find_by(script_id: script.id, ayah_id: id)&.text
    return cached if cached

    forms = words.map { |w| w.text_for(script) }.compact
    forms.join(' ').presence
  end

  def basmalah?
    ayah_number.zero?
  end

  def to_s
    ayah_key
  end
end
