class TajweedWordsPresenter < ApplicationPresenter
  # Rules without a colour in shared/tajweed_color_new.scss
  UNCOLOURED_RULES = %w[madd_al_tamkeen tarqeeq].freeze

  def word
    return @word if defined?(@word)

    @word = Word.find_by(location: params[:id])
  end

  def tajweed_word
    return @tajweed_word if defined?(@tajweed_word)

    @tajweed_word = word && TajweedWord.find_by(word_id: word.id)
  end

  # Words of the ayah from the same tajweed data as the word, for the ayah preview
  def ayah_tajweed_words
    return TajweedWord.none unless tajweed_word

    TajweedWord.where(verse_id: tajweed_word.verse_id, mushaf_id: tajweed_word.mushaf_id).order(:position)
  end

  def tajweed_rules
    @tajweed_rules ||= TajweedRules.new('new')
  end

  # rule name => up to 3 [location, html] example words with only that rule
  # coloured. Taken from the tajweed words this tool edits, or the QPC tajweed
  # text for rules the tool's data doesn't use yet.
  def palette_examples
    Rails.cache.fetch('tajweed-palette-examples', expires_in: 12.hours) do
      tajweed_rules.rules.to_h do |name, index|
        examples = TajweedWord.rule_eq(index).order(:word_id).limit(3).pluck(:location, :text)
        if examples.empty?
          examples = Word.where('text_qpc_hafs_tajweed LIKE ?', "%class=#{name}>%").order(:word_index).limit(3).pluck(:location, :text_qpc_hafs_tajweed)
        end

        [name, examples.map { |location, text| [location, only_rule(text, name)] }]
      end
    end
  end

  def tajweed_rule
    @tajweed_rule ||= TajweedRules.new('new').documentation[params[:rule].to_s.to_sym]
  end

  def only_rule(text, name)
    text.to_s.gsub(%r{<r class=(?!#{Regexp.escape(name)}>)[^>]*>(.*?)</r>}, '\\1')
  end

  def meta_title
    "Tajweed Rules Annotation Tool"
  end

  def meta_description
    "Review and correct the Tajweed rules embedded in Quranic text. Use suggestions to add missing rules or fix incorrect ones for accurate Tajweed annotation."
  end

  def meta_keywords
    'Tajweed rules annotation tool, Tajweed rules online, Quran Tajweed editor, Tajweed correction tool, Online Tajweed editor, Tajweed annotation platform, Fix Tajweed mistakes, Advanced Quran Tajweed'
  end
end
