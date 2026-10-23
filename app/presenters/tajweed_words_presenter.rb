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
    @tajweed_rule ||= tajweed_rules.documentation[rule_key.to_sym]
  end

  def rule_key
    params[:rule].to_s
  end

  # Up to `limit` words with the rule, spread over the Quran, each with the
  # neighbouring word the rule depends on (idgham, ikhfa and the like).
  # Same sources as palette_examples.
  def rule_examples(limit = 12)
    index = tajweed_rules.rules[rule_key]
    return [] unless index

    Rails.cache.fetch("tajweed-rule-examples-#{rule_key}", expires_in: 12.hours) do
      texts = TajweedWord.rule_eq(index).order(:word_id).pluck(:word_id, :text)
      if texts.empty?
        texts = Word.where('text_qpc_hafs_tajweed LIKE ?', "%class=#{rule_key}>%").order(:word_index).pluck(:id, :text_qpc_hafs_tajweed)
      end

      picked = texts.each_slice([texts.size / limit, 1].max).map(&:first).first(limit).to_h
      words = Word.where(id: picked.keys).order(:word_index).to_a
      around = Word.where(word_index: words.flat_map { |w| [w.word_index - 1, w.word_index + 1] }, char_type_name: 'word').index_by(&:word_index)

      words.map do |word|
        html = only_rule(picked[word.id], rule_key)
        # A rule on the first letter usually comes from the word before it
        neighbour = around[html.start_with?("<r class=#{rule_key}>") ? word.word_index - 1 : word.word_index + 1]
        neighbour = nil unless neighbour&.verse_id == word.verse_id

        {
          location: word.location,
          html: html,
          before_text: (neighbour.text_qpc_hafs if neighbour && neighbour.word_index < word.word_index),
          after_text: (neighbour.text_qpc_hafs if neighbour && neighbour.word_index > word.word_index)
        }
      end
    end
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
