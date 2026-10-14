# The Quran test database.
#
# The Quran-side tables (QuranApiRecord) have no schema.rb; their structure is
# kept as a schema-only dump in db/quran_structure.sql, taken from the dev
# database. Specs run against quran_test, built from that dump and filled with
# the fixture slice under spec/fixtures/qiraat.
#
#   rake qiraat:test_db:prepare       # (re)create quran_test from db/quran_structure.sql
#   rake qiraat:test_db:dump_schema   # refresh db/quran_structure.sql from the dev Quran db
#   rake qiraat:test_db:fixtures      # regenerate spec/fixtures/qiraat from the dev db and
#                                     # the pinned upstream files (rake qiraat:fetch first)
require 'json'
require 'csv'
require 'fileutils'

namespace :qiraat do
  namespace :test_db do
    STRUCTURE_PATH = Rails.root.join('db', 'quran_structure.sql')
    TEST_DB = 'quran_test'
    FIXTURE_DIR = Rails.root.join('spec', 'fixtures', 'qiraat')

    # Verses in the slice: all of al-Fatihah, the start of al-Baqarah, Ayat
    # al-Kursi (split in three editions), and the three word-level edge cases:
    # 9:100 (Bazzi-only word 25685, after تَجۡرِي), 40:26 (word 60522 missing in five
    # editions), 72:16 (one Hafs word covering numbers 73950 and 73951),
    # plus the two ayahs where QUL segments differently from quran-text:
    # 15:7 (QUL splits one word) and 37:130 (QUL joins two).
    SLICE_VERSE_KEYS = (1..7).map { |a| "1:#{a}" } + %w[2:1 2:2 2:3 2:255 9:100 9:101 15:7 37:130 40:26 72:16]
    SLICE_WORD_NUMBERS = [25685, 60522, 69720, 73950, 73951].freeze
    SLICE_MUSHAF_IDS = [5].freeze # KFGQPC Hafs, unicode

    def qiraat_dev_db_name
      Verse.connection_db_config.database
    end

    desc "Create #{TEST_DB} from #{STRUCTURE_PATH.relative_path_from(Rails.root)}"
    task prepare: :environment do
      abort 'run in development or test' unless Rails.env.development? || Rails.env.test?
      ActiveRecord::Base.connection_handler.clear_all_connections!
      exists = `psql -d postgres -Atc "select 1 from pg_database where datname = '#{TEST_DB}'"`.strip == '1'
      system('dropdb', '--force', TEST_DB) || abort('dropdb failed') if exists
      system('createdb', TEST_DB) || abort('createdb failed')
      system('psql', '-q', '-v', 'ON_ERROR_STOP=1', '-d', TEST_DB, '-f', STRUCTURE_PATH.to_s) || abort('loading structure failed')
      tables = `psql -d #{TEST_DB} -Atc "select count(*) from information_schema.tables where table_schema in ('quran','audio','content','media','i18n')"`.strip
      puts "#{TEST_DB} ready: #{tables} tables"
    end

    desc "Dump the dev Quran database schema (no data) to #{STRUCTURE_PATH.relative_path_from(Rails.root)}"
    task dump_schema: :environment do
      abort 'development only' unless Rails.env.development?
      db = qiraat_dev_db_name
      system('pg_dump', '--schema-only', '--no-owner', '--no-privileges', '--no-comments', '-f', STRUCTURE_PATH.to_s, db) || abort('pg_dump failed')
      # pg_dump 17 emits settings older servers reject; keep the file loadable on 16
      cleaned = STRUCTURE_PATH.read.lines.reject { |l| l.start_with?('SET transaction_timeout', '\\restrict', '\\unrestrict') }.join
      STRUCTURE_PATH.write(cleaned)
      copies = File.foreach(STRUCTURE_PATH).count { |l| l.start_with?('COPY ') }
      abort("#{STRUCTURE_PATH} contains #{copies} COPY statements; expected 0") unless copies.zero?
      puts "wrote #{STRUCTURE_PATH} from #{db} (#{File.size(STRUCTURE_PATH)} bytes, 0 data rows)"
    end

    desc 'Regenerate the fixture slice under spec/fixtures/qiraat'
    task fixtures: :environment do
      abort 'development only' unless Rails.env.development?
      upstream = Rails.root.join('tmp', 'qiraat', 'upstream')
      abort 'run rake qiraat:fetch first' unless upstream.join('quran-text/data/word-index.csv').exist?
      FileUtils.mkdir_p(FIXTURE_DIR.join('qul'))
      FileUtils.mkdir_p(FIXTURE_DIR.join('upstream'))

      verses = Verse.unscoped.where(verse_key: SLICE_VERSE_KEYS).order(:id).to_a
      chapter_ids = verses.map(&:chapter_id).uniq.sort
      words = Word.unscoped.where(verse_id: verses.map(&:id)).order(:id).to_a
      mushafs = Mushaf.where(id: SLICE_MUSHAF_IDS).order(:id).to_a
      mushaf_words = MushafWord.where(mushaf_id: SLICE_MUSHAF_IDS, verse_id: verses.map(&:id)).order(:id).to_a
      mushaf_pages = MushafPage.where(mushaf_id: SLICE_MUSHAF_IDS, page_number: mushaf_words.map(&:page_number).uniq).order(:id).to_a

      write = lambda do |name, rows|
        path = FIXTURE_DIR.join('qul', "#{name}.json")
        path.write(JSON.pretty_generate(rows.map(&:attributes)))
        puts "  qul/#{name}.json: #{rows.size} rows"
      end
      write.call('char_types', CharType.order(:id).to_a)
      write.call('counting_systems', CountingSystem.order(:id).to_a)
      write.call('qiraat', Qiraah.unscoped.order(:id).to_a)
      write.call('riwayat', Riwayah.order(:id).to_a)
      write.call('scripts', Script.order(:id).to_a)
      write.call('resource_contents', ResourceContent.where(id: Script.pluck(:word_resource_content_id, :ayah_resource_content_id).flatten.compact).order(:id).to_a)
      write.call('chapters', Chapter.where(id: chapter_ids).order(:id).to_a)
      write.call('verses', verses)
      write.call('words', words)
      write.call('mushafs', mushafs)
      write.call('mushaf_pages', mushaf_pages)
      write.call('mushaf_words', mushaf_words)

      keyset = verses.map { |v| [v.chapter_id, v.verse_number] }.to_set
      surahs = chapter_ids.to_set

      # word-index.csv: rows whose Hafs coordinates fall in the slice, plus the edge numbers
      src = upstream.join('quran-text/data/word-index.csv')
      rows = CSV.read(src, headers: true)
      keep = rows.select do |r|
        SLICE_WORD_NUMBERS.include?(r['number'].to_i) ||
          (r['hafs_surah'].present? && keyset.include?([r['hafs_surah'].to_i, r['hafs_ayah'].to_i]))
      end
      CSV.open(FIXTURE_DIR.join('upstream/word-index.csv'), 'w') do |csv|
        csv << rows.headers
        keep.each { |r| csv << r.fields }
      end
      puts "  upstream/word-index.csv: #{keep.size} rows"

      # ayah-map.json: entries for the slice verses
      am = JSON.parse(upstream.join('quran-text/data/ayah-map.json').read)
      am['ayahs'] = am['ayahs'].select { |e| keyset.include?([e['surah'], e['ayah']]) }
      FIXTURE_DIR.join('upstream/ayah-map.json').write(JSON.pretty_generate(am))
      puts "  upstream/ayah-map.json: #{am['ayahs'].size} entries"

      # differences.json: words in the slice verses or the edge numbers
      df = JSON.parse(upstream.join('quran-text/data/differences.json').read)
      df['words'] = df['words'].select do |w|
        SLICE_WORD_NUMBERS.include?(w['number']) || (w['hafs'] && keyset.include?([w['hafs']['surah'], w['hafs']['ayah']]))
      end
      df['count'] = df['words'].size
      FIXTURE_DIR.join('upstream/differences.json').write(JSON.pretty_generate(df))
      puts "  upstream/differences.json: #{df['words'].size} words"

      # counting.json: every system, with ayah_ends and disputed_points cut to the
      # shared-number ranges of the slice surahs (ranges come from catalog.json)
      catalog = JSON.parse(upstream.join('quran-text/data/catalog.json').read)
      ranges = catalog['surahs'].select { |s| surahs.include?(s['number']) }.map { |s| (s['first_number']..s['last_number']) }
      in_slice = ->(n) { ranges.any? { |r| r.cover?(n) } }
      ct = JSON.parse(upstream.join('quran-text/data/counting.json').read)
      ct['systems'].each_value { |sys| sys['ayah_ends'] = sys['ayah_ends'].select { |n| in_slice.call(n) } }
      ct['disputed_points'] = ct['disputed_points'].select { |d| surahs.include?(d['kufi'].split(':').first.to_i) }
      ct['note_fixture'] = "ayah_ends and disputed_points limited to surahs #{surahs.to_a.sort.join(', ')} by rake qiraat:test_db:fixtures"
      FIXTURE_DIR.join('upstream/counting.json').write(JSON.pretty_generate(ct))
      puts "  upstream/counting.json: #{ct['systems'].size} systems, #{ct['systems']['kufi']['ayah_ends'].size} kufi ends, #{ct['disputed_points'].size} disputed points"

      # small files copied whole
      %w[catalog.json].each do |f|
        FileUtils.cp(upstream.join('quran-text/data', f), FIXTURE_DIR.join('upstream', f))
        puts "  upstream/#{f}: copied"
      end
      %w[qiraat.json counting-systems.json printed-editions.json].each do |f|
        FileUtils.cp(upstream.join('qiraat-ayah-map/data', f), FIXTURE_DIR.join('upstream', f))
        puts "  upstream/#{f}: copied"
      end
      FIXTURE_DIR.join('README.md').write(<<~MD)
        # Fixture slice for the riwayah specs

        Generated by `rake qiraat:test_db:fixtures` from the dev Quran database and the
        pinned upstream files in `config/qiraat_sources.yml`. Do not edit by hand; Quranic
        text here is byte-for-byte from the sources.

        * `qul/` — the reference tables (char_types, counting_systems, qiraat, riwayat, scripts and the resource_contents they link) in full, plus rows of
          chapters, verses, words, mushaf 5 pages and words for the slice
          verses: #{SLICE_VERSE_KEYS.join(', ')}
        * `upstream/` — the matching rows of quran-text `word-index.csv`, `ayah-map.json`,
          `differences.json`, `counting.json` (slice surahs), plus `catalog.json` and the
          qiraat-ayah-map reference files copied whole.

        Loaded into `quran_test` by `QiraatFixtures.load!` (spec/support/qiraat.rb).
      MD
      puts "wrote #{FIXTURE_DIR}"
    end
  end
end
