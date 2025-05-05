namespace :import do
  desc "Import English translations from lemmas.txt into Lemma.en_translations (jsonb array)"
  task import_lemma_translations: :environment do
    file_path = Rails.root.join('lib', 'data', 'lemmas.txt')
    entries   = File.readlines(file_path, chomp: true).reject(&:blank?)

    found_count      = 0
    not_found_count  = 0
    duplicate_count  = 0
    unmatched_keys   = []

    puts "\nStarting import of English translations...\n\n"

    entries.each_with_index do |line, idx|
      buckwalter, eng = line.split("\t", 2).map(&:strip)
      next unless buckwalter.present? && eng.present?

      arabic = convert_buckwalter_to_arabic(buckwalter)
      clean  = remove_diacritics(arabic)

      lemma = Lemma.find_by(text_clean: clean)
      if lemma
        existing = lemma.en_translations || []
        if existing.include?(eng)
          duplicate_count += 1
        else
          existing << eng
          lemma.update!(en_translations: existing)
          found_count += 1
        end
      else
        not_found_count += 1
        unmatched_keys << { index: idx + 1, buckwalter: buckwalter, clean: clean }
      end
    end

    puts "\n Import Summary:"
    puts "   Total entries       : #{entries.size}"
    puts "   Successfully added  : #{found_count}"
    puts "   Duplicates skipped  : #{duplicate_count}"
    puts "   Not found in DB     : #{not_found_count}"

    if unmatched_keys.any?
      puts "\n Unmatched entries (showing first 10):"
      unmatched_keys.first(10).each do |u|
        puts " - Line ##{u[:index]}: Buckwalter='#{u[:buckwalter]}', Clean='#{u[:clean]}'"
      end
      puts " ...and #{unmatched_keys.size - 10} more" if unmatched_keys.size > 10
    end

    puts "\n Import task complete!"
  end

  def convert_buckwalter_to_arabic(bw)
    mapping = {
      "'" => '', '>' => 'ا', '<' => 'ا', "&" => '', "}" => '', "{" => 'ا',
      "A" => 'ا', "b" => 'ب', "t" => 'ت', "v" => 'ث', "j" => 'ج',
      "H" => 'ح', "x" => 'خ', "d" => 'د', "*" => 'ذ', "r" => 'ر',
      "z" => 'ز', "s" => 'س', "$" => 'ش', "S" => 'ص', "D" => 'ض',
      "T" => 'ط', "Z" => 'ظ', "E" => 'ع', "g" => 'غ', "f" => 'ف',
      "q" => 'ق', "k" => 'ك', "l" => 'ل', "m" => 'م', "n" => 'ن',
      "h" => 'ه', "w" => 'و', "Y" => 'ى', "y" => 'ي',
      /[FNKaui~o^#`_:;,\.\!\-\+\%\]\[]/ => ''
    }
    bw.chars.map { |c|
      map_key = mapping.keys.find { |k| k.is_a?(Regexp) ? k.match?(c) : k == c }
      mapping[map_key] || c
    }.join
  end

  def remove_diacritics(str)
    str.gsub(/[\u064B-\u065F\u0670]/, '').gsub('ـ', '')
  end
end
