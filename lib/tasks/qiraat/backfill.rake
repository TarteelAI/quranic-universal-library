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
