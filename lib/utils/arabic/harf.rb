module Utils
  module Arabic
    class Harf
      attr_accessor :harf

      protected
      def has_codepoint?(code)
        harf.codepoints.include? code
      end
    end
  end
end