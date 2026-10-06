# Imports from the pinned upstream files (rake qiraat:fetch first).
#
#   DRY_RUN=1 rake qiraat:import:script[warsh]   # report only
#   rake qiraat:import:script[warsh]             # one quran-text edition into scripts + word_texts
#   rake qiraat:import:scripts                   # the six non-Hafs editions
#   rake qiraat:verify:scripts                   # counts against the quran-text catalog
namespace :qiraat do
  namespace :import do
    UPSTREAM_TEXT = Rails.root.join('tmp', 'qiraat', 'upstream', 'quran-text', 'data')
    NON_HAFS_EDITIONS = %w[shubah warsh qalun duri susi bazzi].freeze

    def qiraat_import_edition(key)
      path = UPSTREAM_TEXT.join('mushaf', "#{key}.json")
      abort "#{path} missing; run rake qiraat:fetch" unless path.exist?
      dry = ENV['DRY_RUN'].present?
      t = Time.now
      r = Qiraat::Import::ScriptText.new(key: key, path: path, dry_run: dry, logger: nil).call
      puts format('%-7s printed=%d numbers_read=%d rows=%d written=%d deleted=%d joined_rows=%s spanning=%s missing=%s unmapped=%s %s(%.1fs)',
                  key, r[:printed_words], r[:numbers_read], r[:rows], r[:written], r[:deleted], r[:joined_rows].uniq.size, r[:spanning_rows].size,
                  r[:missing_numbers].inspect, r[:unmapped_numbers].inspect, dry ? 'DRY RUN ' : '', Time.now - t)
      abort("#{key}: unmapped numbers #{r[:unmapped_numbers].inspect}") if r[:unmapped_numbers].any?
    end

    desc 'Import one quran-text edition (hafs shubah warsh qalun duri susi bazzi) into scripts and word_texts'
    task :script, [:key] => :environment do |_t, args|
      abort 'usage: rake qiraat:import:script[warsh]' if args[:key].blank?
      qiraat_import_edition(args[:key])
    end

    desc 'Import the six non-Hafs quran-text editions'
    task scripts: :environment do
      NON_HAFS_EDITIONS.each { |k| qiraat_import_edition(k) }
    end

    desc 'Import quran-text differences.json into word_differences'
    task word_differences: :environment do
      path = UPSTREAM_TEXT.join('differences.json')
      abort "#{path} missing; run rake qiraat:fetch" unless path.exist?
      dry = ENV['DRY_RUN'].present?
      r = Qiraat::Import::WordDifferences.new(path: path, dry_run: dry).call
      puts "word_differences#{dry ? ' (DRY RUN)' : ''}: in file #{r[:in_file]}, rows #{r[:rows]}, merged onto one QUL row #{r[:merged].inspect}, unmapped #{r[:unmapped].inspect}, deleted #{r[:deleted]}"
      r[:by_status].sort.each { |st, n| puts format('  %-16s %d', st, n) }
      abort('unmapped numbers') if r[:unmapped].any?
    end
  end

  namespace :verify do
    desc 'Verify word_differences against the quran-text file (P3.5)'
    task word_differences: :environment do
      data = JSON.parse(Rails.root.join('tmp', 'qiraat', 'upstream', 'quran-text', 'data', 'differences.json').read)
      by_status = data['words'].group_by { |w| w['status'] }.transform_values(&:size)
      failed = []
      check = lambda do |name, actual, expected|
        ok = actual == expected
        failed << name unless ok
        puts format('  %-44s %s %s', name, ok ? 'OK ' : 'FAIL', ok ? actual.inspect : "#{actual.inspect} expected #{expected.inspect}")
      end
      check.call('rows = file entries - merged pair', WordDifference.count, data['count'] - 1)
      by_status.each { |st, n| check.call("status #{st}", WordDifference.where(status: st).count, st == 'word_boundary' ? n - 1 : n) }
      check.call('25685 missing in hafs', WordDifference.find_by(word_id: Word.unscoped.find_by(number: 25_685)&.id)&.missing&.include?('hafs'), true)
      check.call('60522 missing in five', WordDifference.find_by(word_id: Word.unscoped.find_by(location: '40:26:13')&.id)&.missing&.sort, %w[bazzi duri qalun susi warsh])
      check.call('every row has a known status', WordDifference.where.not(status: WordDifference::STATUSES).count, 0)
      abort("#{failed.size} check(s) failed") if failed.any?
      puts 'word_differences OK'
    end

    desc 'Verify the imported row-backed scripts against the quran-text catalog (P3.3)'
    task scripts: :environment do
      catalog = JSON.parse(Rails.root.join('tmp', 'qiraat', 'upstream', 'quran-text', 'data', 'catalog.json').read)
      counts = catalog['riwayahs'].to_h { |r| [r['key'], r['word_count']] }
      failed = []
      check = lambda do |name, actual, expected|
        ok = actual == expected
        failed << name unless ok
        puts format('  %-52s %s %s', name, ok ? 'OK ' : 'FAIL', ok ? actual.inspect : "#{actual.inspect} expected #{expected.inspect}")
      end
      Qiraat::Import::ScriptText::EDITIONS.each do |key, (slug, _riwayah, _css)|
        script = Script.find_by(slug: slug)
        next unless script

        rows = WordText.for_script(script)
        # printed words minus the ones joined onto one QUL row (Hafs writes 72:16 joined;
        # QUL keeps 37:130 as one row) equals the number of word_texts rows
        joined = Word.unscoped.where.not(number_last: nil).count
        printed = counts.fetch(key)
        expected_rows = printed - rows.where(word_id: Word.unscoped.where.not(number_last: nil).select(:id)).sum { |r| r.text.count(' ') }
        check.call("#{key}: word_texts rows = printed words - joined", rows.count, expected_rows)
        check.call("#{key}: no empty text", rows.where(text: '').count, 0)
        check.call("#{key}: script is row-backed, disabled", [script.storage, script.enabled], ['rows', false])
      end
      bazzi = Script.find_by(slug: 'qpc-bazzi')
      warsh = Script.find_by(slug: 'qpc-warsh')
      if bazzi && warsh
        w25685 = Word.unscoped.find_by(number: 25_685)
        w60522 = Word.unscoped.find_by(number: 60_522)
        check.call('bazzi reads 25685 (مِن, 9:100)', WordText.where(script_id: bazzi.id, word_id: w25685&.id).count, 1)
        check.call('warsh does not read 60522 (أَوۡ, 40:26)', WordText.where(script_id: warsh.id, word_id: w60522&.id).count, 0)
        check.call('warsh keeps the Fatihah basmalah words', WordText.where(script_id: warsh.id, word_id: Word.unscoped.where(verse_key: '1:1', char_type_name: 'word').select(:id)).count, 4)
        check.call('warsh 1:4:1 form', WordText.find_by(script_id: warsh.id, word_id: Word.unscoped.find_by(location: '1:4:1')&.id)&.text, 'مَلِكِ')
      end
      abort("#{failed.size} check(s) failed") if failed.any?
      puts 'scripts OK'
    end
  end
end
