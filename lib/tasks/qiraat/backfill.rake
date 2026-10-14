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
        next if m.script.image?

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
      Word::LEGACY_COLUMN_MUSHAFS.each do |column, legacy|
        derived = Word.mushaf_ids_for_column(column).sort
        legacy_existing = Mushaf.where(id: legacy).pluck(:id).sort
        puts format('  %-32s legacy %-22s derived %-26s %s', column, legacy_existing.inspect, derived.inspect, derived == legacy_existing ? 'same' : 'DIFFERS')
      end
      abort("#{failed.size} mushaf(s) with unexpected cache mismatches") if failed.any?
      puts 'mushaf_scripts OK'
    end
  end
end
