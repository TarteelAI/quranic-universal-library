# Backfills for the multi-riwayah schema. Every task is idempotent, batched,
# accepts DRY_RUN=1, and has a matching rake qiraat:verify:* task.
#
#   DRY_RUN=1 rake qiraat:backfill:word_numbers   # report only
#   rake qiraat:backfill:word_numbers             # write words.number / number_last
#   rake qiraat:verify:word_numbers               # assert the expected counts
namespace :qiraat do
  namespace :backfill do
    desc 'Write the quran-text shared number onto words.number (P2.2)'
    task word_numbers: :environment do
      csv = Rails.root.join('tmp', 'qiraat', 'upstream', 'quran-text', 'data', 'word-index.csv')
      abort "#{csv} missing; run rake qiraat:fetch" unless csv.exist?
      dry = ENV['DRY_RUN'].present?
      puts "backfill word_numbers on #{Word.connection.current_database}#{dry ? ' (DRY RUN)' : ''}"
      t = Time.now
      r = Qiraat::Backfill::WordNumbers.new(csv_path: csv, dry_run: dry).call
      puts "index rows with Hafs coordinates: #{r[:index_rows_with_hafs]}; without: #{r[:index_rows_without_hafs].inspect}"
      puts "QUL word rows: #{r[:qul_word_rows]}; numbered: #{r[:numbered]}; written: #{r[:written]}"
      puts "rows with number_last (one QUL word, several numbers): #{r[:with_number_last].inspect}"
      puts "continuation rows (several QUL words, one number): #{r[:continuation].inspect}"
      puts "ayahs aligned by text: #{r[:text_aligned_ayahs].inspect}"
      puts "ayahs NOT aligned: #{r[:unaligned_ayahs].inspect}"
      puts "positional words whose text differs from the index form: #{r[:text_mismatches]}"
      r[:text_mismatch_samples].each { |loc, qul, idx| puts "    #{loc}  QUL #{qul}  index #{idx}" }
      puts "done in #{(Time.now - t).round(1)}s"
      abort('unaligned ayahs present') if r[:unaligned_ayahs].any?
    end

    desc 'Insert words rows for shared numbers Hafs does not read (P2.3)'
    task missing_words: :environment do
      csv = Rails.root.join('tmp', 'qiraat', 'upstream', 'quran-text', 'data', 'word-index.csv')
      abort "#{csv} missing; run rake qiraat:fetch" unless csv.exist?
      dry = ENV['DRY_RUN'].present?
      puts "backfill missing_words on #{Word.connection.current_database}#{dry ? ' (DRY RUN)' : ''}"
      r = Qiraat::Backfill::MissingWords.new(csv_path: csv, dry_run: dry).call
      puts "numbers without Hafs coordinates: #{r[:candidates].inspect}"
      r[:inserted].each { |i| puts "  #{dry ? 'would insert' : 'inserted'} number #{i.number} at #{i.location} (after #{i.after_location})" }
      puts "already present: #{r[:already_present].inspect}" if r[:already_present].any?
      puts "UNPLACEABLE: #{r[:unplaceable].inspect}" if r[:unplaceable].any?
      abort('unplaceable numbers') if r[:unplaceable].any?
    end
  end

  namespace :verify do
    desc 'Verify words.number against the expected counts (P2.2)'
    task word_numbers: :environment do
      words = Word.unscoped.hafs.where(char_type_name: 'word') # rows other riwayat add (P2.3) are checked by verify:missing_words
      checks = {
        'word rows' => [words.count, 77_432],
        'numbered word rows' => [words.where.not(number: nil).count, 77_431],
        'continuation rows (number NULL)' => [words.where(number: nil).pluck(:location), ['15:7:2']],
        'rows with number_last' => [words.where.not(number_last: nil).pluck(:location).sort, ['37:130:3', '72:16:1']],
        'end rows numbered' => [Word.unscoped.where(char_type_name: 'end').where.not(number: nil).count, 0],
        'distinct numbers covered by Hafs' => [Word.connection.select_value("SELECT count(*) FROM (SELECT number FROM words WHERE number IS NOT NULL AND hafs_reads UNION SELECT generate_series(number, number_last) FROM words WHERE number_last IS NOT NULL AND hafs_reads) n").to_i, 77_433],
        'word 1:4:1' => [Word.unscoped.find_by(location: '1:4:1')&.number, 11],
        'word 40:26:13' => [Word.unscoped.find_by(location: '40:26:13')&.number, 60_522],
        'word 72:16:1' => [Word.unscoped.find_by(location: '72:16:1')&.values_at(:number, :number_last), [73_950, 73_951]]
      }
      failed = checks.reject { |_, (actual, expected)| actual == expected }
      checks.each { |name, (actual, expected)| puts format('  %-36s %s %s', name, actual == expected ? 'OK ' : 'FAIL', actual == expected ? actual.inspect : "#{actual.inspect} expected #{expected.inspect}") }
      abort("#{failed.size} check(s) failed") if failed.any?
      puts 'word_numbers OK'
    end

    desc 'Verify the inserted non-Hafs word rows (P2.3)'
    task missing_words: :environment do
      row = Word.unscoped.find_by(number: 25_685)
      checks = {
        'total word rows (incl. ayah ends)' => [Word.unscoped.count, 83_669],
        'Hafs word rows' => [Word.unscoped.hafs.where(char_type_name: 'word').count, 77_432],
        'non-Hafs word rows' => [Word.unscoped.where(hafs_reads: false).pluck(:location), ['9:100:17.1']],
        '25685 verse / position / sub_position' => [row&.values_at(:verse_key, :position, :sub_position), ['9:100', 17, 1]],
        '25685 has no Hafs text' => [row&.text_qpc_hafs, nil],
        'verse.words of 9:100 hides it' => [Verse.find_by!(verse_key: '9:100').words.where(number: 25_685).count, 0],
        'order places it after 9:100:17' => [Word.where(verse_key: '9:100').pluck(:location).each_cons(2).any? { |a, b| a == '9:100:17' && b == '9:100:17.1' }, true]
      }
      failed = checks.reject { |_, (actual, expected)| actual == expected }
      checks.each { |name, (actual, expected)| puts format('  %-40s %s %s', name, actual == expected ? 'OK ' : 'FAIL', actual == expected ? actual.inspect : "#{actual.inspect} expected #{expected.inspect}") }
      abort("#{failed.size} check(s) failed") if failed.any?
      puts 'missing_words OK'
    end
  end
end

namespace :qiraat do
  namespace :backfill do
    desc 'Detect and set mushafs.script_id from each mushaf\'s cached word text (P3.4)'
    task mushaf_scripts: :environment do
      dry = ENV['DRY_RUN'].present?
      r = Qiraat::Backfill::MushafScripts.new(dry_run: dry, force: ENV['FORCE'].present?).call
      puts "backfill mushaf_scripts on #{Mushaf.connection.current_database}#{dry ? ' (DRY RUN)' : ''}"
      r[:assigned].each { |id, slug| puts "  #{dry ? 'would set' : 'set'} mushaf #{id} (#{Mushaf.find(id).name.strip}) -> #{slug}#{r[:stale][id] ? " (#{r[:stale][id]} stale words)" : ''}" }
      r[:kept].each { |id, slug| puts "  kept mushaf #{id} -> #{slug}" }
      r[:ambiguous].each { |id, slugs| puts "  AMBIGUOUS mushaf #{id}: #{slugs.inspect}" }
      r[:unmatched].each { |id, slugs| puts "  UNMATCHED mushaf #{id} (#{Mushaf.find(id).name.strip}): #{slugs.inspect}" }
      puts "  no cached words and no font match: #{r[:no_words].inspect}" if r[:no_words].any?
    end
  end

  namespace :verify do
    desc 'Verify mushafs.script_id: cached text equals the script column over the whole table; show the fan-out change (P3.4)'
    task mushaf_scripts: :environment do
      # Words whose cache no longer equals the source column, measured 7 Oct 2026
      # over the whole table: drift from past edits (175 on mushaf 14, 26 on 23
      # written by the wrong legacy fan-out, a handful elsewhere). A count above
      # its allowance means a wrong script or new drift. Refreshed in P3.7.
      known_stale = { 1 => 2, 2 => 1, 3 => 9, 5 => 1, 14 => 175, 16 => 7, 17 => 1, 19 => 2, 22 => 1, 23 => 26, 27 => 1 }
      failed = []
      Mushaf.where.not(script_id: nil).order(:id).includes(:script).each do |m|
        # generated mushafs (P5.3) cache the quran-text edition (checked by qiraat:verify:mushaf_layout), not a words column
        next if m.script.image? || !m.script.column? || Mushaf::GENERATED_LAYOUT_SOURCES.include?(m.layout_source)

        col = Word.connection.quote_column_name(m.script.column_name)
        bad = Word.connection.select_value(<<~SQL).to_i
          SELECT count(*) FROM mushaf_words mw JOIN words w ON w.id = mw.word_id
          WHERE mw.mushaf_id = #{m.id} AND mw.char_type_name = 'word' AND mw.text IS DISTINCT FROM w.#{col}
        SQL
        allowed = known_stale.fetch(m.id, 0)
        ok = bad <= allowed
        failed << m.id unless ok
        puts format('  mushaf %-3d %-40s %-26s stale %-5d %s', m.id, m.name.strip[0, 40], m.script.slug, bad, ok ? (bad.zero? ? 'OK' : "OK (known, #{allowed})") : 'FAIL')
      end
      puts "  without script: #{Mushaf.where(script_id: nil).pluck(:id).inspect} (legacy name matching keeps serving them)"
      puts '--- fan-out per column: legacy list vs derived from scripts (a derived superset means caches that went stale before are refreshed from now on)'
      Qiraat::Backfill::MushafScripts::LEGACY_COLUMN_MUSHAFS.each do |column, legacy|
        derived = Word.mushaf_ids_for_column(column).sort
        legacy_existing = Mushaf.where(id: legacy).pluck(:id).sort
        puts format('  %-32s legacy %-22s derived %-26s %s', column, legacy_existing.inspect, derived.inspect, derived == legacy_existing ? 'same' : 'DIFFERS')
      end
      abort("#{failed.size} mushaf(s) with unexpected cache mismatches") if failed.any?
      puts 'mushaf_scripts OK'
    end
  end
end

namespace :qiraat do
  namespace :backfill do
    # what Mushaf#pdf_url returned by id before P5.1 made it a column (the constant left the model in P7.5)
    LEGACY_PDF_URLS = {
      1 => 'https://tafsir.app/m-madinah/1/1',
      2 => 'https://tafsir.app/m-madinah-old/1/1',
      5 => 'https://download.qurancomplex.gov.sa/resources_dev/UthmanicHafs_v18.zip',
      6 => 'https://archive.org/details/AlQuran15LinesQudratullah/page/n609/mode/2up',
      7 => 'https://archive.org/details/AlQuranAlKareem16LinesTajCompany/page/n517/mode/2up'
    }.freeze

    desc 'Set numbering (Kufi), layout_source (manual) and pdf_url on the existing mushafs (P5.1)'
    task mushaf_numbering: :environment do
      dry = ENV['DRY_RUN'].present?
      kufi = AyahNumbering.kufi
      Mushaf.order(:id).each do |m|
        changes = {}
        changes[:numbering_id] = kufi.id if m.numbering_id.nil?
        changes[:layout_source] = 'manual' if m.layout_source.blank?
        changes[:pdf_url] = LEGACY_PDF_URLS[m.id] if m[:pdf_url].blank? && LEGACY_PDF_URLS[m.id]
        next if changes.empty?

        puts "  #{dry ? 'would set' : 'set'} mushaf #{m.id} #{changes.inspect}"
        m.update_columns(changes) unless dry
      end
    end
  end

  namespace :verify do
    desc 'Verify every mushaf has a numbering matching its riwayah and the legacy pdf urls survived (P5.1)'
    task mushaf_numbering: :environment do
      failed = []
      check = lambda do |name, actual, expected|
        ok = actual == expected
        failed << name unless ok
        puts format('  %-50s %s %s', name, ok ? 'OK ' : 'FAIL', ok ? actual.inspect : "#{actual.inspect} expected #{expected.inspect}")
      end
      check.call('mushafs without numbering', Mushaf.where(numbering_id: nil).count, 0)
      manual = Mushaf.where(layout_source: 'manual') # the hand-made (pre-P5.3) layouts; generated ones carry their riwayah's numbering
      check.call('hand-made mushafs on kufi', manual.where(numbering_id: AyahNumbering.kufi.id).count, manual.count)
      check.call('every mushaf has a layout_source', Mushaf.where(layout_source: [nil, '']).count, 0)
      LEGACY_PDF_URLS.each { |id, url| check.call("pdf_url mushaf #{id}", Mushaf.find_by(id: id)&.pdf_url, url) }
      check.call('every mushaf valid', Mushaf.all.reject(&:valid?).map(&:id), [])
      abort("#{failed.size} check(s) failed") if failed.any?
      puts 'mushaf_numbering OK'
    end
  end
end

namespace :qiraat do
  namespace :backfill do
    desc 'Set mushaf_words.ayah_id and mushaf_pages first/last ayah from ayah_mappings (P5.2)'
    task mushaf_ayah_ids: :environment do
      dry = ENV['DRY_RUN'].present?
      conn = MushafWord.connection
      Mushaf.where.not(numbering_id: nil).order(:id).each do |m|
        pending = MushafWord.where(mushaf_id: m.id, ayah_id: nil).where.not(verse_id: nil).count
        pages = MushafPage.where(mushaf_id: m.id).where.not(first_verse_id: nil).where('first_ayah_id IS NULL OR last_ayah_id IS NULL').count
        puts "  mushaf #{m.id} (#{m.numbering.slug}): #{pending} words, #{pages} pages to set#{dry ? ' (DRY RUN)' : ''}"
        next if dry || (pending.zero? && pages.zero?)

        t = Time.now
        # one statement per mushaf: the word's Kufi verse -> the numbering's ayah
        conn.execute(<<~SQL) if pending.positive?
          UPDATE mushaf_words mw
          SET ayah_id = am.ayah_id
          FROM ayah_mappings am
          WHERE mw.mushaf_id = #{m.id.to_i} AND mw.ayah_id IS NULL
            AND am.numbering_id = #{m.numbering_id.to_i} AND am.verse_id = mw.verse_id
        SQL
        # pages are filled from their own verse range, so a mushaf with pages but no cached words (30) is covered too
        conn.execute(<<~SQL) if pages.positive?
          UPDATE mushaf_pages p
          SET first_ayah_id = a1.ayah_id, last_ayah_id = a2.ayah_id
          FROM ayah_mappings a1, ayah_mappings a2
          WHERE p.mushaf_id = #{m.id.to_i} AND (p.first_ayah_id IS NULL OR p.last_ayah_id IS NULL)
            AND a1.numbering_id = #{m.numbering_id.to_i} AND a1.verse_id = p.first_verse_id
            AND a2.numbering_id = #{m.numbering_id.to_i} AND a2.verse_id = p.last_verse_id
        SQL
        puts "    done in #{(Time.now - t).round(1)}s"
      end
    end
  end

  namespace :verify do
    desc 'Verify mushaf_words.ayah_id and the page ayah ranges (P5.2)'
    task mushaf_ayah_ids: :environment do
      failed = []
      check = lambda do |name, actual, expected|
        ok = actual == expected
        failed << name unless ok
        puts format('  %-56s %s %s', name, ok ? 'OK ' : 'FAIL', ok ? actual.inspect : "#{actual.inspect} expected #{expected.inspect}")
      end
      check.call('mushaf_words with a verse but no ayah', MushafWord.where(ayah_id: nil).where.not(verse_id: nil).count, 0)
      check.call('mushaf_words without a word (none yet)', MushafWord.where(word_id: nil).count, 0)
      # Kufi mushafs: ayah_id equals verse_id (Kufi rows take the verse ids)
      kufi_ids = Mushaf.where(numbering_id: AyahNumbering.kufi.id).pluck(:id)
      check.call('kufi mushafs: ayah_id = verse_id everywhere', MushafWord.where(mushaf_id: kufi_ids).where('ayah_id <> verse_id').count, 0)
      check.call('pages with a verse range but no ayah range', MushafPage.where.not(first_verse_id: nil).where(first_ayah_id: nil).or(MushafPage.where.not(last_verse_id: nil).where(last_ayah_id: nil)).count, 0)
      page = MushafPage.find_by(mushaf_id: 5, page_number: 3)
      check.call('mushaf 5 page 3: ayah ids = verse ids of its words', MushafWord.where(mushaf_id: 5, page_number: 3).distinct.pluck(:ayah_id).sort, MushafWord.where(mushaf_id: 5, page_number: 3).distinct.pluck(:verse_id).sort)
      check.call('mushaf 5 page 3: page range', [page&.first_ayah_id, page&.last_ayah_id], [page&.first_verse_id, page&.last_verse_id])
      abort("#{failed.size} check(s) failed") if failed.any?
      puts 'mushaf_ayah_ids OK'
    end
  end
end

namespace :qiraat do
  namespace :backfill do
    desc 'Set audio_segments.ayah_id and audio_files.ayah_id from each recitation numbering (P7.3)'
    task audio_ayah_ids: :environment do
      dry = ENV['DRY_RUN'].present?
      r = Qiraat::Backfill::AudioAyahIds.new(dry_run: dry).call
      puts "audio_ayah_ids#{dry ? ' (DRY RUN)' : ''}: #{r.inspect}"
    end

    desc 'Write number_segments (word timings by shared number) for audio_segments and audio_files (P7.3)'
    task number_segments: :environment do
      dry = ENV['DRY_RUN'].present?
      r = Qiraat::Backfill::NumberSegments.new(dry_run: dry, only: ENV['ONLY'].presence).call
      puts "number_segments#{dry ? ' (DRY RUN)' : ''}: #{r.inspect}"
    end
  end

  namespace :verify do
    desc 'Verify recitation numberings, ayah ids and number_segments (P7.3)'
    task audio_numbering: :environment do
      failed = []
      check = lambda do |name, actual, expected|
        ok = actual == expected
        failed << name unless ok
        puts format('  %-62s %s %s', name, ok ? 'OK ' : 'FAIL', ok ? actual.inspect : "#{actual.inspect} expected #{expected.inspect}")
      end
      kufi = AyahNumbering.kufi
      check.call('recitations without numbering', Recitation.where(numbering_id: nil).count, 0)
      check.call('audio_recitations without numbering', Audio::Recitation.where(numbering_id: nil).count, 0)
      check.call('hafs recitations on kufi', Recitation.where(riwayah_id: Riwayah.hafs.id).where.not(numbering_id: kufi.id).count, 0)
      check.call('audio_segments with a verse but no ayah', Audio::Segment.where.not(verse_id: nil).where(ayah_id: nil).count, 0)
      check.call('audio_files with a verse but no ayah', AudioFile.where.not(verse_id: nil).where(ayah_id: nil).count, 0)
      check.call('kufi segments: ayah_id = verse_id', Audio::Segment.joins(:audio_recitation).where(audio_recitations: { numbering_id: kufi.id }).where('audio_segments.ayah_id <> audio_segments.verse_id').count, 0)
      check.call('segments with timings but no number_segments', Audio::Segment.where.not(segments: nil).where(number_segments: nil).count, 0)
      check.call('audio_files with timings but no number_segments', AudioFile.where.not(segments: [nil, '', '[]']).where(number_segments: nil).count, 0)
      sample = Audio::Segment.where.not(number_segments: nil).first
      if sample
        numbers = sample.verse.words.where(char_type_name: 'word').pluck(:number)
        check.call("sample #{sample.verse_key}: number_segments numbers are the verse words' numbers", (sample.number_segments.map(&:first) - numbers), [])
      end
      idx = Verse.connection.indexes(:audio_segments).find { |i| i.name == 'index_audio_segments_on_audio_file_id_and_ayah_id' }
      check.call('partial unique index (audio_file_id, ayah_id)', [idx&.unique, idx&.where.to_s.delete('()').squeeze(' ')], [true, 'ayah_id IS NOT NULL'])
      abort("#{failed.size} check(s) failed") if failed.any?
      puts 'audio_numbering OK'
    end
  end
end
