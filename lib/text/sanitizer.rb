module Text
  class Sanitizer < BaseSanitizer
    attr_reader :fragment

    def sanitize(text)
      @fragment = super(text, scrubber: Text::Scrubber.new)
      self
    end
  end
end