# == Schema Information
#
# Table name: words
#
#  id                         :integer          not null, primary key
#  audio_url                  :string
#  char_type_name             :string
#  class_name                 :string
#  code_dec                   :integer
#  code_dec_v3                :integer
#  code_hex                   :string
#  code_hex_v3                :string
#  code_v1                    :string
#  code_v2                    :string
#  en_transliteration         :string
#  image_blob                 :text
#  image_url                  :string
#  line_number                :integer
#  line_v2                    :integer
#  location                   :string
#  meta_data                  :jsonb
#  page_number                :integer
#  pause_name                 :string
#  position                   :integer
#  sequence_number            :integer
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
#  text_uthmani_tajweed       :string
#  v2_page                    :integer
#  verse_key                  :string
#  word_index                 :integer
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  chapter_id                 :integer
#  char_type_id               :integer
#  lemma_id                   :integer
#  root_id                    :integer
#  stem_id                    :integer
#  token_id                   :integer
#  topic_id                   :integer
#  verse_id                   :integer
#
# Indexes
#
#  index_words_on_chapter_id       (chapter_id)
#  index_words_on_char_type_id     (char_type_id)
#  index_words_on_lemma_id         (lemma_id)
#  index_words_on_location         (location)
#  index_words_on_position         (position)
#  index_words_on_root_id          (root_id)
#  index_words_on_sequence_number  (sequence_number) UNIQUE
#  index_words_on_stem_id          (stem_id)
#  index_words_on_token_id         (token_id)
#  index_words_on_topic_id         (topic_id)
#  index_words_on_verse_id         (verse_id)
#  index_words_on_verse_key        (verse_key)
#  index_words_on_word_index       (word_index)
#

class Word < QuranApiRecord
  include StripWhitespaces

  MUSHAF_TO_TEXT_ATTR_MAPPING = {
    1 => 'code_v2',
    2 => 'code_v1',
    3 => 'text_indopak',
    4 => 'text_uthmani',
    5 => 'text_qpc_hafs',
    6 => 'text_indopak_nastaleeq',
    7 => 'text_indopak_nastaleeq',
    8 => 'text_indopak_nastaleeq',
    13 => 'text_indopak_nastaleeq',
    14 => 'text_qpc_nastaleeq_hafs',
    15 => 'text_indopak_nastaleeq',
    16 => 'text_indopak_nastaleeq',
    21 => 'text_qpc_hafs_tajweed'
  }

  has_paper_trail on: %i[update destroy], ignore: %i[created_at updated_at]

  belongs_to :verse
  belongs_to :char_type
  belongs_to :topic, optional: true
  belongs_to :token, optional: true
  belongs_to :root, optional: true
  belongs_to :lemma, optional: true
  belongs_to :stem, optional: true

  has_many :word_translations
  has_many :transliterations, as: :resource
  has_many :word_synonyms
  has_many :synonyms, through: :word_synonyms
  has_many :mushaf_words
  has_many :derived_words, class_name: 'Morphology::DerivedWord'
  has_many :morphology_word_segments, class_name: 'Morphology::WordSegment'
  has_one :tajweed_word

  # for eager loading
  has_one :mushaf_word
  has_one :word_translation
 
  # has_one :pause_mark
  has_one :morphology_word, class_name: 'Morphology::Word'

  has_one :ur_translation, -> { where language_id: 174 }, class_name: 'WordTranslation'
  has_one :bn_translation, -> { where language_id: 20 }, class_name: 'WordTranslation'
  has_one :id_translation, -> { where language_id: 67 }, class_name: 'WordTranslation'
  has_one :en_translation, -> { where language_id: 38 }, class_name: 'WordTranslation'
  has_one :zh_translation, -> { where language_id: 185 }, class_name: 'WordTranslation'
  has_one :uz_translation, -> { where language_id: 175 }, class_name: 'WordTranslation'
  has_one :fa_translation, -> { where language_id: 43 }, class_name: 'WordTranslation' # Farsi
  has_one :fr_translation, -> { where language_id: 49 }, class_name: 'WordTranslation' # French
  has_one :tr_translation, -> { where language_id: 167 }, class_name: 'WordTranslation' # Turkish

  has_one :ur_transliteration, -> { where language_name: 'urdu' }, class_name: 'Transliteration', as: :resource

  has_one :arabic_transliteration
  after_update :update_mushaf_word_text

  scope :words, -> { where char_type_id: 1 }
  scope :with_sajdah_marker, -> { where "meta_data ? 'sajdah'" }
  scope :with_optional_sajdah, -> { where("meta_data ->> 'sajdah-type' = 'optional'") }

  scope :with_sajdah_position_overline, -> { where("meta_data ->> 'sajdah-position' LIKE ?", '%overline%') }
  scope :with_sajdah_position_ayah_marker, -> { where("meta_data ->> 'sajdah-position' LIKE ?", '%ayah-marker%') }
  scope :with_sajdah_position_word_ends, -> { where("meta_data ->> 'sajdah-position' LIKE ?", '%word-end%') }

  scope :with_hizb_marker, -> { where "meta_data ? 'hizb'" }
  scope :starts_with_eq, lambda { |letters| QuranWordFinder.new(self).find_by_starting_letter(letters) }
  scope :ends_with_eq, lambda { |letters| QuranWordFinder.new(self).find_by_ending_letter(letters) }
  scope :letters_cont, lambda { |letters| QuranWordFinder.new(self).find_by_letters(letters) }

  default_scope { order 'position asc' }
  alias_attribute :code_v4, :code_v2

  def self.ransackable_scopes(*)
    %i[letters_cont starts_with_eq ends_with_eq]
  end

  def self.without_root
    Word.words.joins("LEFT JOIN roots ON words.root_id = roots.id")
        .where("words.root_id IS NULL OR roots.id IS NULL")
  end

  def self.without_stem
    Word.words.joins("LEFT JOIN stems ON words.stem_id = stems.id")
        .where("words.stem_id IS NULL OR stems.id IS NULL")
  end

  def self.without_lemma
    Word.words.joins("LEFT JOIN lemmas ON words.lemma_id = lemmas.id")
        .where("words.lemma_id IS NULL OR lemmas.id IS NULL")
  end

  def first_word?
    position == 1
  end

  def last_word?
    position == verse.words_count
  end

  def next_word
    Word.where(word_index: word_index + 1).first
  end

  def previous_word
    Word.where(word_index: word_index - 1).first
  end

  def to_s
    location
  end

  def translation_for_language(lang)
    word_translations.where(language_id: lang.id).first
  end

  def char_type_id=(val)
    super(val)
    self.char_type_name = CharType.find(val).name
  end

  def humanize
    "#{location} - #{text_uthmani}"
  end

  def text_for_mushaf(mushaf_id)
    if (attr = MUSHAF_TO_TEXT_ATTR_MAPPING[mushaf_id.to_i])
      send attr
    else
      text = MushafWord.where(word: self, mushaf_id: mushaf_id).first&.text
      text || text_indopak_nastaleeq
    end
  end

  def qa_tajweed_image_url(word_location=nil, format: 'png')
    s, a, w = (word_location || location).split(':')

    if ayah_mark?
      "#{WORDS_CDN}/common/#{a}.png"
    else
      "#{WORDS_CDN}/qa-color/#{s}/#{a}/#{w}.#{format}"
    end
  end

  def rq_tajweed_image_url(format: 'png')
    s, a, w = location.split(':')

    if ayah_mark?
      "#{WORDS_CDN}/common/#{a}.png"
    else
      "#{WORDS_CDN}/rq-color/#{s}/#{a}/#{w}.#{format}"
    end
  end

  def qa_black_image_url(format: 'png')
    s, a, w = location.split(':')

    if ayah_mark?
      "#{WORDS_CDN}/common/#{a}.png"
    else
      "#{WORDS_CDN}/qa-black/#{s}/#{a}/#{w}.#{format}"
    end
  end

  def tajweed_svg_url
    s, a, w = location.split(':')

    if ayah_mark?
      "#{WORDS_CDN}/common/#{a}.svg"
    else
      "#{WORDS_CDN}/svg-tajweed/#{s}/#{a}/#{w}.svg"
    end
  end

  def corpus_image_url
    s, a, w = location.split(':')

    if ayah_mark?
      "#{WORDS_CDN}/common/#{a}.png"
    else
      "#{WORDS_CDN}/corpus/#{s}/#{a}/#{w}.png"
    end
  end

  def tajweed_v4_image_url(format: 'png')
    s, a, w = location.split(':')

    if ayah_mark?
      "#{WORDS_CDN}/common/#{a}.png"
    else
      "#{WORDS_CDN}/v4-tajweed/#{s}/#{a}/#{w}.#{format}"
    end
  end

  def word?
    'word' == char_type_name
  end

  def sajdah?
    text_uthmani.include?('۩') || meta_data&.dig('sajdah')
  end

  def sajdah_number
    if sajdah?
      meta_data&.dig('sajdah') || verse.sajdah_number
    end
  end

  def ayah_mark?
    'end' == char_type_name
  end

  def hizb?
    text_uthmani.include? '۞'
  end

  def meta_data=(val)
    json = Oj.safe_load(val)

    json.keys.each do |key|
      formatted_key = format_meta_key(key)

      if formatted_key != key
        json[formatted_key] = json[key]
        json.delete(key)
      end
    end

    super json
  end

  protected

  def update_mushaf_word_text
    if saved_change_to_attribute?('text_qpc_nastaleeq_hafs') # QPC text with their nastaleeq font
      update_text_for_mushaf([14, 15], text_qpc_nastaleeq_hafs)
      update_ayah_script('text_qpc_nastaleeq_hafs')
    end

    if saved_change_to_attribute?('text_qpc_nastaleeq') # QPC text with Quranwbw font
      update_text_for_mushaf([13, 23], text_qpc_nastaleeq)
      update_ayah_script('text_qpc_nastaleeq')
    end

    if saved_change_to_attribute?('text_indopak_nastaleeq')
      update_text_for_mushaf([6, 7, 8, 17], text_indopak_nastaleeq)
      update_ayah_script('text_indopak_nastaleeq')
    end

    if saved_change_to_attribute?('text_qpc_hafs')
      update_text_for_mushaf(5, text_qpc_hafs)
      update_ayah_script('text_qpc_hafs')
    end

    if saved_change_to_attribute?('text_uthmani') # me_quran
      update_text_for_mushaf(4, text_uthmani)
      update_ayah_script('text_uthmani')
    end

    if saved_change_to_attribute?('text_indopak') # pdms font
      update_text_for_mushaf(3, text_indopak)
      update_ayah_script('text_indopak')
    end

    if saved_change_to_attribute?('code_v1')
      update_text_for_mushaf(2, code_v1)
      update_ayah_script('code_v1')
    end

    if saved_change_to_attribute?('code_v2')
      update_text_for_mushaf([1, 19], code_v2)
      update_ayah_script('code_v2')
    end

    if saved_change_to_attribute?('text_uthmani_tajweed')
      update_text_for_mushaf(16, text_uthmani_tajweed)
      update_ayah_script('text_uthmani_tajweed')
    end

    if saved_change_to_attribute?('text_qpc_hafs_tajweed')
      update_text_for_mushaf(21, text_qpc_hafs_tajweed)
      update_ayah_script('text_qpc_hafs_tajweed')
    end

    if saved_change_to_attribute?('text_digital_khatt')
      update_text_for_mushaf(20, text_digital_khatt)
      update_ayah_script('text_digital_khatt')
    end

    if saved_change_to_attribute?('text_digital_khatt_v1')
      update_text_for_mushaf(22, text_digital_khatt_v1)
      update_ayah_script('text_digital_khatt_v1')
    end

    if saved_change_to_attribute?('text_digital_khatt_indopak')
      update_text_for_mushaf(24, text_digital_khatt_indopak)
      update_ayah_script('text_digital_khatt_indopak')
    end
  end

  def update_text_for_mushaf(mushaf_id, text)
    MushafWord.where(word_id: id, mushaf_id: mushaf_id).update_all text: text
  end

  def update_ayah_script(script_type)
    script_text = verse.words.order('position ASC').reload.pluck(script_type).join(' ')
    verse.update(script_type => script_text)
  end
end
