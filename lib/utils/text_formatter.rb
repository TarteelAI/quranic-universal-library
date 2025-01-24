module Utils
  class TextFormatter
    def initialize(text)
      @text = text
    end

    def format
      @text = @text
                .gsub(/\s<sup/, '<sup') # Remove any whitespace before the footnote<sup> opening tag
                .gsub(/\s{2,}/, ' ') # Remove any double spaces
                .strip # Remove any leading or trailing whitespace

      @text
    end
  end
end