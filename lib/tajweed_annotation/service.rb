# s = TajweedAnnotation::Service.new
# s.add_annotation_on_verse(Verse.find_by(verse_key: '112:4'))
module TajweedAnnotation
  class Service
    attr_accessor :words,
                  :word_rules

    def add_annotation_on_verse(verse)
      @words = []
      word_pos = 0
      ayah_words = verse.words.words

      ayah_words.each do |word|
        word_token = TajweedAnnotation::WordToken.new(word.text_qpc_hafs, word, word_pos, self)
        if word_pos == 0
          word_token.first_word!
        elsif word_pos == ayah_words.size - 1
          word_token.last_word!
        end

        @words << word_token
        word_pos += 1
      end

      @words.each do |word|
        word.letter_tokens.each do |letter_token|
          letter_token.process_rules
        end
      end

      @word_rules = {}
      @words.each do |word|
        letters = []
        tokens = word.letter_tokens
        char_index = 0

        tokens.each do |token|
          rules = token.rules
          token.text.chars.each_with_index do |c, i|
            letters << {
              c: c,
              r: rules[i],
              i: char_index
            }.compact_blank

            char_index += 1
          end
        end

        word_rules[word.word.location] = letters
      end

      @word_rules
    end

    def annotate_words_text(tag = 'r')
      last_word = nil
      words_html = {}
      current_rule = nil
      current_group = ""
      tajweed = TajweedRules.new('new')

      word_rules.each do |w, letters|
        words_html[w] = []

        letters.each_with_index do |l, _i|
          if l[:r] == current_rule
            current_group << l[:c].to_s
          else
            if current_group.present?
              if current_rule
                words_html[w] << "<#{tag} class=#{tajweed.name(current_rule)}>#{current_group}</#{tag}>"
              else
                words_html[w] << current_group
              end
            end

            if l[:r]
              current_rule = l[:r]
              current_group = l[:c]
            else
              words_html[w] << l[:c]
              current_rule = nil
              current_group = ""
            end
          end
        end

        if current_rule.present?
          words_html[w] << "<#{tag} class=#{tajweed.name(current_rule)}>#{current_group}</#{tag}>"
        else
          words_html[w] << current_group
        end

        current_group = ""

        last_word = w
      end

      if current_rule
        words_html[last_word] << "<#{tag} class=#{tajweed.name(current_rule)}>#{current_group}</#{tag}>"
      else
        words_html[last_word] << current_group
      end

      words_html
    end

    def to_html(tag = 'r')
      annotate_words_text(tag).map do |location, html|
        "<span data-location='#{location}'>#{html.join}</span> "
      end.join('')
    end

    def anotated_words
      last_word = nil
      words_html = {}
      current_rule = nil
      current_group = ""
      tajweed = TajweedRules.new('new')

      word_rules.each do |w, letters|
        words_html[w] = []

        letters.each_with_index do |l, _i|
          if l[:r] == current_rule
            current_group << l[:c].to_s
          else
            if current_group.present?
              if current_rule
                words_html[w] << "<#{tag} class=#{tajweed.name(current_rule)}>#{current_group}</#{tag}>"
              else
                words_html[w] << current_group
              end
            end

            if l[:r]
              current_rule = l[:r]
              current_group = l[:c]
            else
              words_html[w] << l[:c]
              current_rule = nil
              current_group = ""
            end
          end
        end

        if current_rule.present?
          words_html[w] << "<#{tag} class=#{tajweed.name(current_rule)}>#{current_group}</#{tag}>"
        else
          words_html[w] << current_group
        end

        current_group = ""

        last_word = w
      end

      if current_rule
        words_html[last_word] << "<#{tag} class=#{tajweed.name(current_rule)}>#{current_group}</#{tag}>"
      else
        words_html[last_word] << current_group
      end

      words_html.map do |location, html|
        "<span data-location='#{location}'>#{html.join}</span> "
      end.join('')
    end
  end
end