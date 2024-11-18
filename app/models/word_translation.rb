# == Schema Information
#
# Table name: word_translations
#
#  id                  :bigint           not null, primary key
#  group_text          :string
#  language_name       :string
#  priority            :integer
#  text                :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  group_word_id       :integer
#  language_id         :integer
#  resource_content_id :integer
#  word_id             :integer
#
# Indexes
#
#  index_word_translations_on_group_word_id            (group_word_id)
#  index_word_translations_on_priority                 (priority)
#  index_word_translations_on_word_id_and_language_id  (word_id,language_id)
#

class WordTranslation < QuranApiRecord
  include StripWhitespaces
  include Resourceable

  has_paper_trail ignore: [:created_at, :updated_at]

  belongs_to :word
  belongs_to :language
  belongs_to :group_word, class_name: 'Word', optional: true

  attr_accessor :word_range_from, :word_range_to

  def create_or_update_group_translation(params)
    range_from = params[:word_range_from].to_i
    range_to = params[:word_range_to].to_i
    primary_word_position = params[:group_word_id].to_i

    unless valid_group_range?(range_from, range_to, primary_word_position)
      errors.add :base, 'Group primary word must be within the range'
      return false
    end

    group_words = fetch_group_words(range_from, range_to)
    primary_word = find_primary_word(group_words, primary_word_position)

    new_group_translations = update_group_translations(group_words, primary_word, params[:group_text])
    remove_outdated_group_translations(language_id, primary_word.id, new_group_translations)
  end

  def primary_in_group?
    group_word_id == word_id
  end

  def has_grouped_translation?
    group_word_id.present?
  end

  def group_primary_translation
    WordTranslation.where(
      language_id: language_id,
      word_id: group_word_id
    ).first
  end

  def group_words_range
    return [word, word] unless has_grouped_translation?

    strong_memoize "word_translaiton_group_range_#{group_word_id || id}" do
      range_words = WordTranslation.where(
        language_id: language_id,
        group_word_id: group_word_id
      ).includes(:word).order('words.position asc')

      [range_words.first.word, range_words.last.word]
    end
  end

  def get_group_text
    if has_grouped_translation?
      if primary_in_group?
        group_text
      else
        "*(#{group_word.position})"
      end
    else
      ''
    end
  end

  protected
  def valid_group_range?(range_from, range_to, group_id)
    (range_from..range_to).include?(group_id)
  end

  def fetch_group_words(range_from, range_to)
    word.verse.words.where(position: range_from..range_to)
  end

  def find_primary_word(group_words, group_word_position)
    group_words.find { |w| w.position == group_word_position }
  end

  def remove_outdated_group_translations(language_id, primary_word_id, new_group_translations)
    WordTranslation.where(language_id: language_id, group_word_id: primary_word_id)
                   .where.not(id: new_group_translations)
                   .update_all(group_word_id: nil, group_text: '')
  end

  def update_group_translations(group_words, primary_word, group_text)
    group_words.map do |w|
      translation = WordTranslation.where(
        language_id: language_id,
        word_id: w.id
      ).first_or_initialize

      translation.group_word_id = primary_word.id
      translation.group_text = w.id == primary_word.id ? group_text : ''
      translation.save(validate: false)

      translation.id
    end
  end

  def attributes_to_strip
    [:language_name, :text]
  end
end
