module Utils
  class QpcGlyph
    def self.generate_page
      glyphs = []
      0.upto(194) do |t|
        glyph = (64337+t+(t>96?33:0))
        #"u#{glyph.to_s(16)}"
        glyphs.push glyph.to_s(16)
      end

      glyphs
    end
  end
end