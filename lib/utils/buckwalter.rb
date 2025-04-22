# frozen_string_literal: true
# Utils::Buckwalter.new.to_arabic("bi+")
module Utils
  class Buckwalter
    # Using this mapping for Arabic to English root transformation
    # https://en.wikipedia.org/wiki/Buckwalter_transliteration
    MAPPING = {
      'ا' => 'A',
      'آ' => 'A',
      'ب' => 'b',
      'ت' => 't',
      'ث' => 'v',
      'ج' => 'j',
      'ح' => 'H',
      'خ' => 'x',
      'د' => 'd',
      'ذ' => '*',
      'ر' => 'r',
      'ز' => 'z',
      'س' => 's',
      'ش' => '$',
      'ص' => 'S',
      'ض' => 'D',
      'ط' => 'T',
      'ظ' => 'Z',
      'ع' => 'E',
      'غ' => 'g',
      'ف' => 'f',
      'ق' => 'q',
      'ك' => 'k',
      'ل' => 'l',
      'م' => 'm',
      'ن' => 'n',
      'ه' => 'h',
      'و' => 'w',
      'ي' => 'y',
      'ی' => 'y'
    }.freeze

    BUCKWALTER_MAPPING = {
      "'": 'ء', '>': 'أ', '&': 'ؤ', '<': 'إ', '}': 'ئ', 'A': 'ا', 'b': 'ب',
      'p': 'ة', 't': 'ت', 'v': 'ث', 'j': 'ج', 'H': 'ح', 'x': 'خ', 'd': 'د',
      '*': 'ذ', 'r': 'ر', 'z': 'ز', 's': 'س', '$': 'ش', 'S': 'ص', 'D': 'ض',
      'T': 'ط', 'Z': 'ظ', 'E': 'ع', 'g': 'غ', '_': 'ـ', 'f': 'ف', 'q': 'ق',
      'k': 'ك', 'l': 'ل', 'm': 'م', 'n': 'ن', 'h': 'ه', 'w': 'و', 'Y': 'ى',
      'y': 'ي', 'F': 'ً', 'N': 'ٌ', 'K': 'ٍ', 'a': 'َ', 'u': 'ُ', 'i': 'ِ',
      '~': 'ّ', 'o': 'ْ', '^': 'ٓ', '#': 'ٔ', '`': 'ٰ', '{': 'ٱ', ':': 'ۜ',
      '@': '۟', '"': '۠', '[': 'ۢ', ';': 'ۣ', ',': 'ۥ', '.': 'ۦ', '!': 'ۨ',
      '-': '۪', '+': '۫', '%': '۬', ']': 'ۭ'
    }.freeze

    def to_arabic(string)
      string.chars.map do |c|
        BUCKWALTER_MAPPING[c.to_sym]
      end.join
    end

    def to_buckwalter(string)
      string.chars.map do |c|
        MAPPING[c.to_s]
      end.join
    end
  end
end
