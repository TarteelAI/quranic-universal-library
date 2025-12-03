require "sqlite3"

class ExportQuranFts
  DB_PATH = Rails.root.join("tmp", "search-data.sqlite")
  MUQATTAAT_LETTERS = {
    'الم' => 'الف لام ميم',
    'الر' => 'الف لام را',
    'المر' => 'الف لام ميم را',
    'كهيعص' => 'كاف ها يا عين صاد',
    'طه' => 'طا ها',
    'طسم' => 'طا سين ميم',
    'طس' => 'طا سين',
    'يس' => 'يا سين',
    'ص' => 'صاد',
    'حم' => 'حا ميم',
    'عسق' => 'عين سين قاف',
    'ق' => 'قاف',
    'ن' => 'نون'
  }

  def self.run
    new.export
  end

  def export
    File.delete(DB_PATH) if File.exist?(DB_PATH)

    db = SQLite3::Database.new(DB_PATH.to_s)
    db.results_as_hash = true

    create_tables(db)

    insert_surahs(db)
    insert_ayahs(db)
    optimize_table(db)
    db.close
    puts "FTS export complete: #{DB_PATH}"
  end

  private

  def create_tables(db)
    # CREATE VIRTUAL TABLE ayah_index USING fts5(
    #                                         term,
    #                                         key UNINDEXED,
    #                                         tokenize = 'trigram'
    #                                       );

    # categories 'L*'
    db.execute_batch <<~SQL
            CREATE VIRTUAL TABLE surah_index USING fts5(
              term,
              key UNINDEXED,
              tokenize = "unicode61 remove_diacritics 2 categories 'L*'"
            );

      CREATE VIRTUAL TABLE ayah_index_unicode USING fts5(
        term,
        key UNINDEXED,
        tokenize = "unicode61 remove_diacritics 2 categories 'L*'"
      );

      CREATE VIRTUAL TABLE ayah_index_trigram USING fts5(
        term,
        key UNINDEXED,
        tokenize = 'trigram'
      );
    SQL
  end

  protected

  def insert_surahs(db)
    Chapter.find_each do |chapter|
      terms = [
        chapter.name_simple.downcase,
        chapter.name_arabic,
        chapter.name_complex.downcase,
        chapter.id.to_s
      ]

      chapter.navigation_search_records.each do |search|
        next if search.text.match(/\d+/) || roman_numeral?(search.text)

        term = search.text.downcase
        terms << term

        if term.include?('al ') || term.include?('an ')
          terms << term.sub(/^(al|an) /, '\1').strip
        end

        # An nas => Al nas
        if term.include?('an ')
          terms << term.sub(/^(an) /, 'al ').strip
        end
      end

      terms = terms.map { |term| normalize(term) }

      terms.uniq.each do |term|
        db.execute <<~SQL, [term, chapter.id.to_s]
          INSERT INTO surah_index (term, key)
          VALUES (?, ?);
        SQL
      end
    end
  end

  def insert_ayahs(db)
    Verse.includes(:verse_root, :verse_stem, :verse_lemma).find_each do |verse|
      transliterations = Translation.where(
        resource_content_id: [1561, 1562],
        verse_id: verse.id
      )

      terms = [
        normalize_arabic(verse.text_uthmani),
        normalize_arabic(verse.text_uthmani_simple),
        normalize_arabic(verse.text_imlaei),
        normalize_arabic(verse.text_qpc_hafs.gsub(/[٠١٢٣٤٥٦٧٨٩]/, '')),
        normalize_arabic(verse.text_imlaei_simple),
        normalize_arabic(verse.verse_stem&.text_madani),
        normalize_arabic(verse.verse_lemma&.text_madani),
        normalize_arabic(verse.verse_root&.value),
      ].compact_blank

      if verse.has_harooq_muqattaat?
        terms += replace_haroof_muqattaat(verse.text_imlaei_simple)
      end

      terms += add_special_ayah_terms(verse)

      transliterations.each do |tr|
        terms << normalize_transliteration(tr)
      end

      terms.compact_blank.uniq.each do |term|
        # db.execute <<~SQL, [term, verse.verse_key]
        #  INSERT INTO ayah_index (term, key)
        #  VALUES (?, ?);
        # SQL

        db.execute <<~SQL, [term, verse.verse_key]
          INSERT INTO ayah_index_unicode (term, key)
          VALUES (?, ?);
        SQL

        # insert into trigram index
        db.execute <<~SQL, [term, verse.verse_key]
          INSERT INTO ayah_index_trigram (term, key)
          VALUES (?, ?);
        SQL
      end
    end
  end

  def replace_haroof_muqattaat(text)
    return [] if text.blank?

    replaced_text = text

    text.split(/\s/).each do |part|
      if MUQATTAAT_LETTERS[part]
        replaced_text = replaced_text.sub(part, MUQATTAAT_LETTERS[part])
      end
    end

    [replaced_text]
  end

  def add_special_ayah_terms(verse)
    if verse.verse_key == '2:255'
      ['ayatul kursi', 'ayat al-kursi']
    else
      []
    end
  end

  def optimize_table(db)
    db.execute "INSERT INTO surah_index(term) VALUES('optimize');"
    db.execute "INSERT INTO ayah_index_trigram(term) VALUES('optimize');"
    db.execute "INSERT INTO ayah_index_unicode(term) VALUES('optimize');"
  end

  HAFS_WAQF_FOR_PHRASE = ["ۖ", "ۗ", "ۚ", "ۚ", "ۜ", "ۢ", "ۨ", "ۭ"]
  HAFS_WAQF_WITH_SIGNS = ["ـ", "ۖ", "ۗ", "ۘ", "ۚ", "ۛ", "ۜ", "۞", "ۢ", "ۦ", "ۧ", "ۨ", "۩", "۪", "۬", "ۭ"]
  INDOPAK_WAQF = ["ۛ", "ٚ", "ؔ", "ؕ", "ۥ", "ۚ", "۪", "۠", "ۙ", "ؗ", "۫", "ۘ", "ۗ", "۬", "ۙ", "۬", "ۦ"]
  EXTRA_CHARS = ['', '', '', '', '‏', ',', '‏', '​', '', '‏', "\u200f"]
  WAQF_REG = Regexp.new((HAFS_WAQF_WITH_SIGNS + INDOPAK_WAQF + EXTRA_CHARS).join('|'))

  TASHKEEL_MATCHERS = [
    [/[آٱأإ]/, 'ا'],
    [/[ٰ]/, 'ا'],
    [/يؤ/, 'يو'],
    [/[ؤئ]/, 'ء'],
    [/ة/, 'ه'],
    [/[ىی]/, 'ي'],
    [/[ًٌٍَُِّْـ]/, ''],
    [/۪/, ''],
    [/۫/, ''],
    [/[،؛؟؞.!]/, '']
  ]

  def normalize_arabic(text)
    return if text.blank?

    TASHKEEL_MATCHERS.each do |pattern, replacement|
      text = text.gsub(pattern, replacement)
    end

    remove_diacritics(text)
  end

  def remove_diacritics(text)
    return if text.blank?

    diacritics_regex = /[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640\u200C-\u200F]/ # Harakat, tatweel, and joiners
    punctuation_regex = /[.,\/#!$%\^&\*;:{}=\-_`~()\"'؟،؛«»…٪]/ # Arabic + Western punctuation
    space_regex = /\s+/ # Multiple spaces

    text.unicode_normalize(:nfc)
        .gsub(diacritics_regex, '') # Remove tashkeel, tatweel, and zero-width marks
        .gsub(punctuation_regex, ' ') # Replace punctuation with space
        .tr("\u00A0\u200B\u200C\u200D", ' ') # Replace non-breaking & zero-width spaces
        .gsub(space_regex, ' ') # Collapse multiple spaces
        .strip # Trim both ends
  end

  def normalize(text)
    text = text.downcase
    text = text.gsub(/\p{Mn}/, '')
    t = I18n.transliterate(text)
    text = t unless t.include?('?')
    text.gsub(/[-]|['']|\b(suresi|surasi|surat|surah|sura|ch|chapter|سورہ|سورت|سورة)\b/, ' ')
        .gsub(/\s+/, ' ').strip
  end

  def normalize_transliteration(tr)
    if tr.resource_content_id == 1561
      normalize_tajweed_transliteration tr.text
    else
      normalize_rtf_transliteration tr.text
    end
  end

  def normalize_rtf_transliteration(text)
    return '' if text.nil? || text.strip.empty?

    s = text.dup

    # 1) Remove <b>...</b> blocks entirely (silent letters)
    s.gsub!(/<b[^>]*>.*?<\/b>/mi, '')

    # 2) Remove markup tags but KEEP inner text for <u>, <i>, <em>, <span>, <strong> etc.
    s.gsub!(/<\/?(?:u|i|em|span|strong)[^>]*>/i, '')

    # 3) Remove any remaining tags (defensive)
    s.gsub!(/<\/?[^>]+>/, '')

    # 4) Basic HTML entity cleanup (common ones)
    s.gsub!(/&nbsp;|&amp;|&lt;|&gt;/i, ' ')

    # 5) Normalize weird apostrophes / hamza markers etc.
    s.gsub!(/[’‘`ʿʾ]/, "'")

    # 6) Replace common separators with space (hyphen, slash, parentheses, semicolon, colon, comma, dot)
    s.gsub!(/[-\/();:,\.\[\]]+/, ' ')

    # 7) Preserve ASCII only (leave letters, apostrophe and spaces); non-ascii -> space
    #    We do this after tag removal so <u>/<b> etc don't remain.
    s = s.encode('utf-8', invalid: :replace, undef: :replace, replace: '')
    s.gsub!(/[^A-Za-z'\s]/, ' ')

    # 8) Lowercase for consistent processing
    s.downcase!

    # 9) Normalize repeated uppercase-A artifacts (after downcase they are 'a' runs)
    #    and collapse long vowel runs to single vowel (to increase recall).
    s.gsub!(/a{2,}/, 'a')
    s.gsub!(/i{2,}/, 'i')
    s.gsub!(/u{2,}/, 'u')
    # map ee -> i (commonly ee represents ī)
    s.gsub!(/e{2,}/, 'i')
    # map oo -> u (commonly ū)
    s.gsub!(/o{2,}/, 'u')

    # 10) Collapse doubled consonants (people type doubles inconsistently)
    s.gsub!(/([b-df-hj-np-tv-z])\1+/, '\1')

    # 11) Condense stray repeated apostrophes and trim them from edges
    s.gsub!(/'{2,}/, "'")
    s.gsub!(/\s*'\s*/, "'")
    s.gsub!(/^'+|'+$/, '')

    # 12) Conservative token fixes & heuristics (tuned to 1562 style)
    replacements = {
      # bismi and variants
      /\bbismil?\b/ => 'bismi',
      /\bbismillahh?\b/ => 'bismillah',
      /\bbismi\s*allah\b/ => 'bismillah',
      /\bbsm\b/ => 'bismi',

      # Allah
      /\ballahh?\b/ => 'allah',

      # qaala / qaalo / qaalu variants -> normalize to "qala" / "qalu"
      /\bq+a+l+a+\b/ => 'qala',
      /\bq+a+l+o+\b/ => 'qalu', # qaalo -> qalu
      /\bq+a+l+u+\b/ => 'qalu',

      # wa-iz / waith variants (waiz, waith, wa-iz, wai-th) -> "wa iz"
      /\bwa[ -]?i(?:z|th)?\b/ => 'wa iz',
      /\bwaith\b/ => 'wa iz',
      /\bwaiz\b/ => 'wa iz',

      # Connectors normalization
      /\bwa+n\b/ => 'wa n', # extra artifact guard

      # Definite article artifacts: keep 'al' as separate token if glued; skip 'allah' because handled above
      # Insert a space after 'al' when it is stuck to the next letters (e.g., "alrrahman" -> "al rahman")
      /\bal([b-df-hj-np-tv-z]{2,})/ => 'al \1',

      # common small normalizations
      /\binnee\b/ => 'inni',
      /\ba+a+lama\b/ => 'aalama', # fallback style
      /\binn?ah?u\b/ => 'innahu',
      /\bbil?l?ah?i\b/ => 'billi', # defensive (rare)
    }

    replacements.each { |pat, sub| s.gsub!(pat, sub) }

    # 13) Remove stray short tokens that are only punctuation/spaces (already removed above), normalize spacing
    s.gsub!(/\s+/, ' ')
    s.strip!
    s
  end

  def normalize_tajweed_transliteration(text)
    return '' if text.nil? || text.strip.empty?

    s = text.dup

    # 1) Remove bracketed / suffix markers (u), (n), (ti), etc.
    s.gsub!(/\([^)]*\)/, ' ')

    # 2) Replace hyphens and semicolons/commas with spaces
    s.gsub!(/[-;,:\.]+/, ' ')

    # 3) Replace apostrophes with simple '
    s.gsub!(/[’‘`ʿʾ]/, "'")

    # 4) Remove elongation markers like ^ at line start or middle
    s.gsub!(/\^/, ' ')

    # 5) Normalize spaces around apostrophes (like ya'lamoon)
    s.gsub!(/\s*'\s*/, "'")

    # 6) Lowercase all
    s.downcase!

    # 7) Collapse long vowel sequences
    s.gsub!(/a{2,}/, 'a')
    s.gsub!(/i{2,}/, 'i')
    s.gsub!(/u{2,}/, 'u')
    s.gsub!(/e{2,}/, 'i')
    s.gsub!(/o{2,}/, 'u')

    # 8) Collapse doubled consonants (non-vowels)
    s.gsub!(/([b-df-hj-np-tv-z])\1+/, '\1')

    # 9) Normalize common Arabic transliteration particles
    replacements = {
      /\bdeenil?\b/ => 'deen',
      /\bwa[\-]?\b/ => 'wa',
      /\bwal?\b/ => 'wa',
      /\ballahh?\b/ => 'allah',
      /\billaahh?\b/ => 'allah',
      /\bwa\-lillah?\b/ => 'walillah',
      /\bwa\-laa\b/ => 'wala',
      /\bwa\-iz\b/ => 'wa iz',
      /\bqaala\b/ => 'qala',
      /\bqaaloo\b/ => 'qalu',
      /\byaaa[\-]?\b/ => 'ya',
      /\byaaa[\-]?\b/ => 'ya',
      /\biyyaaka\b/ => 'iyyaka',
      /\bittaqul?\b/ => 'ittaqoo',
      /\bmu'mineen\b/ => 'mumineen',
      /\bmuslimeen\b/ => 'muslimeen',
      /\bfil[\-]?\b/ => 'fil',
      /\bfee\b/ => 'fi',
      /\bbismil\b/ => 'bismillah',
      /\balhamdu\b/ => 'alhamdu',
      /\bar[\-]?rahman/i => 'ar rahman',
      /\bar[\-]?raheem/i => 'ar raheem',
      /\bsubhaan/i => 'subhan'
    }
    replacements.each { |pat, sub| s.gsub!(pat, sub) }

    # 10) Remove leftover non-letters
    s.gsub!(/[^a-z'\s]/, ' ')

    # 11) Collapse multiple spaces
    s.gsub!(/\s+/, ' ')
    s.strip!
    s
  end

  def roman_numeral?(value)
    s = value.strip
    !!(s =~ /\AM{0,3}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})\z/i)
  end
end

