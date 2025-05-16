namespace :import do
  desc "Import English translations from lemmas.txt into Lemma.en_translations (jsonb array)"
  task import_lemma_translations: :environment do
    file_path = Rails.root.join('tmp', 'lemmas.txt')
    Utils::Downloader.download("https://static-cdn.tarteel.ai/qul/data/lemmas.txt", file_path)
    entries   = File.readlines(file_path, chomp: true).reject(&:blank?)

    found_count      = 0
    missing  = []
    duplicate  = []
    unmatched_keys   = []
    buck = Utils::Buckwalter.new

    entries.each_with_index do |line, idx|
      buckwalter, translations = line.split("\t", 2).map(&:strip)
      next if buckwalter.blank? || translations.blank?

      arabic = convert_buckwalter_to_arabic(buckwalter)
      arabic2= buck.to_arabic(buckwalter)
      clean  = remove_diacritics(arabic)
      clean2= remove_diacritics(arabic2)

      lemma = Lemma.where(text_clean: [clean, clean2]).or(Lemma.where(text_madani: [arabic, arabic2])).first

      if lemma
        existing = lemma.en_translations || []

        if existing.include?(translations)
          duplicate << buckwalter
        else
          existing << translations
          lemma.update!(en_translations: existing)
          found_count += 1
        end
      else
        missing << buckwalter
      end
    end

    puts "Import Summary:"
    puts "Total entries       : #{entries.size}"
    puts "Successfully added  : #{found_count}"
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
