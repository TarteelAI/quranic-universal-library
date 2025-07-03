module TajweedAnnotation
  class WordToken
    attr_reader :word,
                :letter_tokens,
                :letters,
                :text,
                :text_service,
                :position,
                :word_position

    def initialize(text, word, position, text_service)
      @text = text
      @word = word
      @position = position
      @letter_tokens = []
      @letters = []
      @text_service = text_service

      word_util = WordsUtil.new
      p = 0
      char_position = 0

      tokens = word_util.split_chars_with_tashkeel(text)
      tokens.each_with_index do |chunk, token_index|
        token = LetterToken.new(chunk, p, char_position, self)

        if token_index == 0
          token.mark_as_first_letter!
        elsif token_index == tokens.size - 1
          token.mark_as_last_letter!
        end

        @letter_tokens << token
        p += 1
        char_position += chunk.length
      end
    end

    def first_word!
      @word_position = 'first'
    end

    def last_word!
      @word_position = 'last'
    end

    def first_word?
      @word_position == 'first'
    end

    def last_word?
      @word_position == 'last'
    end

    def is_allah_word?
      # TODO: use regexp
      word_text = word.text_uthmani_simple.remove_diacritics
      ["للَّه","لله", "الله"].detect do |c|
        word_text.include?(c)
      end
    end

    def next_word
      text_service.words[position + 1]
    end

    def previous_word
      text_service.words[position - 1]
    end
  end
end