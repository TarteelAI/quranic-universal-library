require "sqlite3"

class ExportQuranFts
  DB_PATH = Rails.root.join("tmp", "search-data.sqlite")

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

    #"SELECT * FROM docs WHERE docs MATCH '"lin* app*"';"
    # SELECT * FROM docs WHERE docs MATCH 'sqlite NEAR/2 acid NEAR/2 relational';
    # SELECT * FROM email WHERE email MATCH 'fts5' ORDER BY rank;
    # SELECT * FROM ft WHERE ft MATCH 'b : (uvw AND xyz)';
    # prefix index, for speeding up prefix search
    # hello*
    # CREATE VIRTUAL TABLE ft USING fts5(a, b, prefix=2, prefix=3);
    # test different tokenizer
    # trigram, porter,ascii, unicode61, icu
    # porter tokenerizer has stemming
    # CREATE VIRTUAL TABLE ft USING fts5(x, tokenize = 'porter unicode61 remove_diacritics 1');
    db.close
    puts "FTS export complete: #{DB_PATH}"
  end

  private

  def create_tables(db)
    db.execute_batch <<~SQL
      CREATE VIRTUAL TABLE surah_index USING fts5(
        term,
        key UNINDEXED,
        tokenize = 'porter unicode61 remove_diacritics 1'
      );

      CREATE VIRTUAL TABLE ayah_index USING fts5(
        term,
        key UNINDEXED,
        tokenize = 'porter unicode61 remove_diacritics 1'
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
        resource_content_id: [1561, 57, 1566],
        verse_id: verse.id
      )

      terms = [
        remove_diacritics(verse.text_uthmani),
        verse.text_uthmani_simple,
        remove_diacritics(verse.text_imlaei),
        verse.text_imlaei_simple,
        normalize_words(verse.verse_stem&.text_madani),
        normalize_words(verse.verse_lemma&.text_madani),
        normalize_words(verse.verse_root&.value),
      ].compact_blank

      transliterations.each do |tr|
        terms << normalize(tr.text)
      end

      terms.uniq.each do |term|
        db.execute <<~SQL, [term, verse.verse_key]
          INSERT INTO ayah_index (term, key)
          VALUES (?, ?);
        SQL
      end
    end
  end

  def optimize_table(db)
    db.execute "INSERT INTO surah_index(term) VALUES('optimize');"
    db.execute "INSERT INTO ayah_index(term) VALUES('optimize');"
  end

  HAFS_WAQF_FOR_PHRASE = ["ۖ", "ۗ", "ۚ", "ۚ", "ۜ", "ۢ", "ۨ", "ۭ"]
  HAFS_WAQF_WITH_SIGNS = ["ـ", "ۖ", "ۗ", "ۘ", "ۚ", "ۛ", "ۜ", "۞", "ۢ", "ۦ", "ۧ", "ۨ", "۩", "۪", "۬", "ۭ"]
  INDOPAK_WAQF = ["ۛ", "ٚ", "ؔ", "ؕ", "ۥ", "ۚ", "۪", "۠", "ۙ", "ؗ", "۫", "ۘ", "ۗ", "۬", "ۙ", "۬", "ۦ"]
  EXTRA_CHARS = ['', '', '', '', '‏', ',', '‏', '​', '', '‏', "\u200f"]
  WAQF_REG = Regexp.new((HAFS_WAQF_WITH_SIGNS + INDOPAK_WAQF + EXTRA_CHARS).join('|'))

  def remove_diacritics(text)
    return if text.to_s.presence.blank?

    text = text.to_s.remove_diacritics
    text.gsub(WAQF_REG, '')
        .gsub(160.chr("UTF-8"), '')
        .strip
  end

  def normalize(text)
    text = text.downcase
    text = text.gsub(/\p{Mn}/, '')
    t = I18n.transliterate(text)
    text = t unless t.include?('?')
    text.gsub(/[-]|['’]|\b(suresi|surasi|surat|surah|sura|chapter|سورہ|سورت|سورة)\b/, ' ')
        .gsub(/\s+/, ' ').strip
  end

  def normalize_words(text)
    return if text.to_s.presence.blank?
    remove_diacritics(text)
  end
end
