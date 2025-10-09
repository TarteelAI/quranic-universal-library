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

    db.execute_batch <<~SQL
      CREATE VIRTUAL TABLE surah_index USING fts5(
        term,
        key UNINDEXED,
        tokenize = 'unicode61 remove_diacritics 1'
      );

CREATE VIRTUAL TABLE ayah_index_unicode USING fts5(
  term,
  key UNINDEXED,
  tokenize = 'unicode61 remove_diacritics 2'
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
        resource_content_id: [1561], #1566, 57
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
        terms << normalize(tr.text)
      end

      terms.compact_blank.uniq.each do |term|
        #db.execute <<~SQL, [term, verse.verse_key]
        #  INSERT INTO ayah_index (term, key)
        #  VALUES (?, ?);
        #SQL

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
    diacritics_regex = /[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640\u200C-\u200F]/
    punctuation_regex = /[.,\/#!$%\^&\*;:{}=\-_`~()\"'؟،«»…]/
    space_regex = /\s+/

    text.unicode_normalize(:nfc)
        .gsub(diacritics_regex, '')
        .gsub(punctuation_regex, '')
        .gsub(space_regex, ' ')
        .strip
  end

  def normalize(text)
    text = text.downcase
    text = text.gsub(/\p{Mn}/, '')
    t = I18n.transliterate(text)
    text = t unless t.include?('?')
    text.gsub(/[-]|['']|\b(suresi|surasi|surat|surah|sura|chapter|سورہ|سورت|سورة)\b/, ' ')
        .gsub(/\s+/, ' ').strip
  end
end
