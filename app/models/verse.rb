# == Schema Information
#
# Table name: verses
#
#  id                         :integer          not null, primary key
#  code_v1                    :string
#  code_v2                    :string
#  hizb_number                :integer
#  image_url                  :text
#  image_width                :integer
#  juz_number                 :integer
#  manzil_number              :integer
#  mushaf_juzs_mapping        :jsonb
#  mushaf_pages_mapping       :jsonb
#  page_number                :integer
#  pause_words_count          :integer          default(0)
#  rub_el_hizb_number         :integer
#  ruku_number                :integer
#  sajdah_number              :integer
#  sajdah_type                :string
#  surah_ruku_number          :integer
#  text_digital_khatt         :string
#  text_digital_khatt_indopak :string
#  text_digital_khatt_v1      :string
#  text_imlaei                :string
#  text_imlaei_simple         :string
#  text_indopak               :string
#  text_indopak_nastaleeq     :string
#  text_qpc_hafs              :string
#  text_qpc_hafs_tajweed      :string
#  text_qpc_nastaleeq         :string
#  text_qpc_nastaleeq_hafs    :string
#  text_uthmani               :string
#  text_uthmani_simple        :string
#  text_uthmani_tajweed       :text
#  v2_page                    :integer
#  verse_index                :integer
#  verse_key                  :string
#  verse_number               :integer
#  words_count                :integer
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  chapter_id                 :integer
#  verse_lemma_id             :integer
#  verse_root_id              :integer
#  verse_stem_id              :integer
#
# Indexes
#
#  index_verses_on_chapter_id          (chapter_id)
#  index_verses_on_hizb_number         (hizb_number)
#  index_verses_on_juz_number          (juz_number)
#  index_verses_on_manzil_number       (manzil_number)
#  index_verses_on_rub_el_hizb_number  (rub_el_hizb_number)
#  index_verses_on_ruku_number         (ruku_number)
#  index_verses_on_verse_index         (verse_index)
#  index_verses_on_verse_key           (verse_key)
#  index_verses_on_verse_lemma_id      (verse_lemma_id)
#  index_verses_on_verse_number        (verse_number)
#  index_verses_on_verse_root_id       (verse_root_id)
#  index_verses_on_verse_stem_id       (verse_stem_id)
#  index_verses_on_words_count         (words_count)
#

class Verse < QuranApiRecord
  include NavigationSearchable
  include StripWhitespaces

  has_paper_trail on: %i[update destroy], ignore: %i[created_at updated_at]

  belongs_to :chapter, inverse_of: :verses, counter_cache: true
  belongs_to :verse_root, optional: true
  belongs_to :verse_lemma, optional: true
  belongs_to :verse_stem, optional: true

  has_many :tafsirs
  has_many :words
  has_many :mushaf_words
  has_many :morphology_words, class_name: 'Morphology::Word'
  has_many :verse_pages
  has_many :actual_words, -> { where char_type_id: true }, class_name: 'Word'
  has_many :media_contents, as: :resource
  has_many :translations
  has_many :transliterations, as: :resource
  has_many :audio_files
  has_many :recitations, through: :audio_files
  has_many :roots, through: :words
  has_many :stems, through: :words
  has_many :lemmas, through: :words
  has_many :phrase_verses, class_name: 'Morphology::PhraseVerse'
  has_many :verse_topics
  has_many :topics, through: :verse_topics

  has_many :arabic_transliterations
  has_many :word_translations, through: :words, source: 'word_translation'

  # For eager loading
  has_one :audio_segment, class_name: 'Audio::Segment'
  has_one :ur_transliteration, -> { where resource_content_id: 130 }, class_name: 'Translation', as: :resource
  has_one :translation

  accepts_nested_attributes_for :arabic_transliterations
  accepts_nested_attributes_for :word_translations

  alias_attribute :code_v4, :code_v2

  def has_harooq_muqattaat?
    [
      '2:1',
      '3:1',
      '7:1',
      '10:1',
      '11:1',
      '12:1',
      '13:1',
      '14:1',
      '15:1',
      '19:1',
      '20:1',
      '26:1',
      '27:1',
      '28:1',
      '29:1',
      '30:1',
      '31:1',
      '32:1',
      '36:1',
      '38:1',
      '40:1',
      '41:1',
      '42:1',
      '42:2',
      '43:1',
      '44:1',
      '45:1',
      '46:1',
      '50:1',
      '68:1'
  ].include?(verse_key)
  end 

  def to_s
    verse_key
  end

  def image_url(type: 'v1', format: 'png')
    "#{AYAH_CDN}/#{type}/#{chapter_id}_#{verse_number}.#{format}"
  end

  def verse_phrases
    Morphology::PhraseVerse.includes(:phrase).where(verse_id: id)
  end

  def self.verses_with_missing_translations(language_id)
    query = "left join word_translations on words.id = word_translations.word_id AND word_translations.language_id = #{language_id}"
    verse_ids = Word.words.select('words.verse_id').joins(query).where("words.id is null OR word_translations.text = '' OR  word_translations.text IS NULL")

    where(id: verse_ids)
  end

  def get_matching_verses
    Morphology::MatchingVerse.where(verse_id: id).order('score desc')
  end

  def next_ayah
    Verse.where(verse_index: verse_index + 1).first
  end

  def previous_ayah
    Verse.where(verse_index: verse_index - 1).first
  end

  def first_ayah?
    verse_number == 1
  end

  def last_ayah?
    verse_number == chapter.verses_count
  end

  def self.verses_with_no_arabic_translitration
    Verse
      .select('verses.*, count(words.*) as missing_transliteration_count')
      .joins(:words)
      .joins('left OUTER JOIN arabic_transliterations on arabic_transliterations.word_id = words.id')
      .where('arabic_transliterations.text is null')
      .where('words.char_type_id = 1')
      .preload(:actual_words)
      .group('verses.id')
  end

  def self.verses_with_missing_arabic_translitration
    Verse
      .select('verses.*, count(words.*) as missing_transliteration_count')
      .joins(:words)
      .joins('left OUTER JOIN arabic_transliterations on arabic_transliterations.word_id = words.id')
      .where('arabic_transliterations.id is null')
      .where('words.char_type_id = 1')
      .preload(:actual_words)
      .group('verses.id')
  end

  def self.verse_with_words_and_arabic_transliterations
    Verse
      .select('verses.*, count(words.*) as total_words, count(arabic_transliterations.*) as total_transliterations')
      .joins(:words)
      .joins('left OUTER JOIN arabic_transliterations on arabic_transliterations.word_id = words.id')
      .where('words.char_type_id = 1')
      .group('verses.id')
  end

  def self.verse_with_full_arabic_transliterations
    verse_with_words_and_arabic_transliterations
      .having('count(arabic_transliterations.*) = count(words.*)')
  end

  def arabic_transliteration_progress
    total_words = self['total_words'] || actual_words.size
    missing_count = if self['missing_transliteration_count']
                      self['missing_transliteration_count']
                    elsif self['total_transliterations']
                      (total_words - self['total_transliterations'].to_i)
                    else
                      total_words - arabic_transliterations.size
                    end

    (100 - (missing_count / total_words.to_f) * 100).to_i.abs
  end

  def find_verses_by_word_sequence(sequence)
    words = sequence.split('*').map do |w|
      w.strip
    end
    words_condition = words.map { |word| "verses.text_uthmani LIKE '%#{word}%'" }.join(' and ')

    Verse.joins(:words).where(words_condition).distinct
  end

  def find_related_verses_by_roots
    target_verse = self

    Verse
      .joins(words: [:word_root])
      .where('word_roots.root_id IN (:roots)',
             roots: target_verse.roots.pluck(:id))
      .where.not(id: target_verse.id)
      .distinct
      .select('verses.*, COUNT(words.id) AS word_match_count')
      .group('verses.id')
      .order('word_match_count DESC')
  end

  def self.find_related_verses(verse_id)
    target_verse = find(verse_id)

    Verse
      .joins(words: %i[lemma stem root])
      .where('roots.id IN (:roots) OR stems.id IN (:stems) OR lemmas.lemma_id IN (:lemmas)',
             roots: target_verse.roots.pluck(:id),
             stems: target_verse.stems.pluck(:id),
             lemmas: target_verse.words.pluck(:id)
      )
      .where.not(id: verse_id)
      .distinct
      .select('verses.*, COUNT(words.id) AS word_match_count')
      .group('verses.id')
      .order('word_match_count DESC')
  end

  def word_translation_progress(language_id)
    total_words = words.words.count
    words_with_translations = WordTranslation.where(word_id: words.pluck(:id), language_id: language_id).count
    missing_count = [total_words - words_with_translations, 0].max

    (100 - (missing_count / total_words.to_f) * 100).to_i.abs
  end

  def last_verse?
    verse_number == chapter.verses_count
  end

  def first_verse?
    verse_number == 1
  end

  def update_word_translations(params)
    params[:word_translations_attributes].values.each do |word_translation|
      next unless word_translation['text'].presence

      translation = WordTranslation.where(word_id: word_translation[:word_id],
                                          language_id: word_translation[:language_id]).first_or_initialize
      translation.text = word_translation['text'].presence
      translation.save
    end
  end

  def self.find_by_id_or_key(id)
    if id.to_s.include? ':'
      where(verse_key: id).first
    else
      where(verse_key: id).or(where(id: id.to_s)).first
    end
  end
end
