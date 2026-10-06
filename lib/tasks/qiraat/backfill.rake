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
  end

  namespace :verify do
    desc 'Verify words.number against the expected counts (P2.2)'
    task word_numbers: :environment do
      words = Word.unscoped.where(char_type_name: 'word')
      checks = {
        'word rows' => [words.count, 77_432],
        'numbered word rows' => [words.where.not(number: nil).count, 77_431],
        'continuation rows (number NULL)' => [words.where(number: nil).pluck(:location), ['15:7:2']],
        'rows with number_last' => [words.where.not(number_last: nil).pluck(:location).sort, ['37:130:3', '72:16:1']],
        'end rows numbered' => [Word.unscoped.where(char_type_name: 'end').where.not(number: nil).count, 0],
        'distinct numbers covered' => [Word.connection.select_value("SELECT count(*) FROM (SELECT number FROM words WHERE number IS NOT NULL UNION SELECT generate_series(number, number_last) FROM words WHERE number_last IS NOT NULL) n").to_i, 77_433],
        'word 1:4:1' => [Word.unscoped.find_by(location: '1:4:1')&.number, 11],
        'word 40:26:13' => [Word.unscoped.find_by(location: '40:26:13')&.number, 60_522],
        'word 72:16:1' => [Word.unscoped.find_by(location: '72:16:1')&.values_at(:number, :number_last), [73_950, 73_951]]
      }
      failed = checks.reject { |_, (actual, expected)| actual == expected }
      checks.each { |name, (actual, expected)| puts format('  %-36s %s %s', name, actual == expected ? 'OK ' : 'FAIL', actual == expected ? actual.inspect : "#{actual.inspect} expected #{expected.inspect}") }
      abort("#{failed.size} check(s) failed") if failed.any?
      puts 'word_numbers OK'
    end
  end
end
