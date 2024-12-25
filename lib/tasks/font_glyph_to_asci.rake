namespace :font_glyph_to_ascii do
  desc 'Converts a font glyph to ascii'

  task convert: :environment do |t, args|
    surah_glyphs = (0xE001..0xE001 + 113).map { |code| code.to_s(16).upcase }

    CSV.open("v4_surah_name_glyphs.csv", "wb") do |csv|
      csv << ["Surah", "Name", "Unicode", "Ligature", "Icon"]

      surah_glyphs.each_with_index do |unicode, i|
        csv << [
          i + 1,
          Chapter.find(i + 1).name_simple,
          unicode,
          "s#{(i + 1).to_s.rjust(3, '0')}, surah#{(i + 1).to_s.rjust(3, '0')}",
          [unicode.to_i(16)].pack("U*")
        ]
      end
    end

    glyphs = []
    surah_glyphs.split(",").each_with_index do |a, i|
      glyphs << "#{a}: #{i + 1} - #{Chapter.find(i + 1).name_simple}"
    end

    def add_to_hex(hex_value, number)
      new_hex_value = hex_value.to_i(16) + number
      new_hex_value.to_s(16).upcase
    end

    add_to_hex("FC45", 113).chr
  end
end

