class String
  DIALECTIC_CHARS_REGEXP = /۟|\u200F|\ufd67|\u06ed|\uf658|\u06d7|\ufd6b|\ufd6f|\uE01B|\u06DB|\ufd7f|\ufd50|\u06E8|\u06D8|\uFEFF|\u2002|\u200B|\u0614|\u06E2|\uE022|\u06DA|\u06E4|\u06D9|\u06D6| ۖ||ۙ |\u0651|\uE01C|\u06E1|\uE01E|\u06DA|\u0615|\u06E6|\ufe80|\u06E5|\u064B|\u0670|\u0FBCx|\u0FB5x|\u0FBB6|\u0FE7x|\u0FC62|\u0FC61|\u0FC60|\u0FDF0|\u0FDF1|\u0066D|\u0061F|\u060F|\u060E|\u060D|\060C|\u060B|\u064C|\u064D|\u064E|\u064F|\u0650|\u0651|\u0652|\u0653|\u0654|\u0655|\u0656|\0657|\u0658|ٰ|/
  ALIF_REGEXP = /أ|\u0671|\u0625|\u0621|\u0623|آ/

  def remove_diacritics(replace_hamza: true)
    simple = self.gsub(DIALECTIC_CHARS_REGEXP, '')

    if replace_hamza
      simple.gsub(ALIF_REGEXP, 'ا').gsub('ئ', 'ي').strip
    else
      simple
    end
  end

  def self.nbsp
    [160].pack('U*')
  end

  # Copy text to clipboard. Works great on OSx
  def copy_to_clipboard
    str = self.to_s
    IO.popen('pbcopy', 'w') { |f| f << str }
    str
  end

  # https://en.wikibooks.org/wiki/Algorithm_Implementation/Strings/Longest_common_substring#Ruby
  # find longest common sub string
  def intersection(str)
    return '' if [self, str].any?(&:empty?)

    matrix = Array.new(self.length) { Array.new(str.length) { 0 } }
    intersection_length = 0
    intersection_end = 0
    self.length.times do |x|
      str.length.times do |y|
        next unless self[x] == str[y]
        matrix[x][y] = 1 + (([x, y].all?(&:zero?)) ? 0 : matrix[x - 1][y - 1])

        next unless matrix[x][y] > intersection_length
        intersection_length = matrix[x][y]
        intersection_end = x
      end
    end
    intersection_start = intersection_end - intersection_length + 1

    slice(intersection_start..intersection_end)
  end

  def lcs_start(word1, word2)
    end1 = word1.length - 1
    end2 = word2.length - 1
    pos = 0

    while pos <= end1 && pos <= end2
      if word1[pos] != word2[pos]
        return word1[0...pos]
      else
        pos += 1
      end
    end
  end

  def lcs_end(word1, word2)
    pos1 = word1.length - 1
    pos2 = word2.length - 1

    while pos1 >= 0 && pos2 >= 0
      if word1[pos1] != word2[pos2]
        return word1[(pos1 + 1)..-1]
      else
        pos1 -= 1
        pos2 -= 1
      end
    end
  end
end

