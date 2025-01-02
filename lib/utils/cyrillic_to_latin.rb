# frozen_string_literal: true

module Utils
  class CyrillicToLatin
    UZ_ALPHABET = {
      'а': 'a', 'б': 'b', 'д': 'd', 'э': 'e', 'е': 'e', 'ф': 'f', 'г': 'g',
      'А': 'A', 'Б': 'B', 'Д': 'D', 'Э': 'E', 'Е': 'E', 'Ф': 'F', 'Г': 'G',
      'ҳ': 'h', 'и': 'i', 'ж': 'j', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n',
      'Ҳ': 'H', 'И': 'I', 'Ж': 'J', 'К': 'K', 'Л': 'L', 'М': 'M', 'Н': 'N',
      'о': 'o', 'п': 'p', 'қ': 'q', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
      'О': 'O', 'П': 'P', 'Қ': 'Q', 'Р': 'R', 'С': 'S', 'Т': 'T', 'У': 'U',
      'в': 'v', 'х': 'x', 'й': 'y', 'з': 'z', 'ў': 'o`', 'ғ': 'g`', 'ц': 'ts',
      'В': 'V', 'Х': 'X', 'Й': 'Y', 'З': 'Z', 'Ў': 'O`', 'Ғ': 'G`', 'Ц': 'Ts',
      'ш': 'sh', 'ч': 'ch', 'ё': 'yo', 'ю': 'yu', 'я': 'ya', 'йe': 'ye',
      'Ш': 'Sh', 'Ч': 'Ch', 'Ё': 'Yo', 'Ю': 'Yu', 'Я': 'Ya', 'Йe': 'Ye',
      'ъ': "'"
    }.freeze

    UZ_VOWELS = %w[А а Э э И и О о У у Ў ў].freeze

    REG_CX = /сҳ/im
    REG_B = /ь/im

    def to_latin(text)
      cyril = text.gsub(REG_CX, "с'ҳ").gsub(REG_B, '').split('')
      latin = []

      cyril.each_with_index do |word, index|
        latin << convert_chars(word, index, cyril)
      end

      latin.join('')
    end

    protected

    def convert_chars(cyril, i, array)
      if UZ_ALPHABET[cyril.to_sym]
        cyril = handle_ye(cyril, i, array) if cyril === 'Е' || cyril === 'е'

        cyril = handle_ts(cyril, i, array) if cyril === 'Ц' || cyril === 'ц'

        UZ_ALPHABET[cyril.to_sym]
      else
        cyril
      end
    end

    def handle_ye(cyril, index, array)
      previous_code = array[index - 1].ord
      beginning = index === 0 || [10, 13, 32].include?(previous_code)
      after_vowel = UZ_VOWELS.include?(array[index - 1])

      if beginning || after_vowel
        cyril === 'Е' ? 'Йe' : 'йe'
      else
        cyril
      end
    end

    def handle_ts(cyril, index, array)
      after_vowel = index.positive? && UZ_VOWELS.include?(array[index - 1])

      if after_vowel
        cyril
      else
        cyril === 'Ц' ? 'С' : 'с'
      end
    end
  end
end
