require 'csv'
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

    desc 'Build the six madhhab numberings from quran-text counting.json (P4.2)'
    task :numberings, [:systems] => :environment do |_t, args|
      counting = UPSTREAM_TEXT.join('counting.json')
      catalog = UPSTREAM_TEXT.join('catalog.json')
      abort "#{counting} missing; run rake qiraat:fetch" unless counting.exist?
      dry = ENV['DRY_RUN'].present?
      systems = args[:systems].presence&.split(/[ ,]+/)
      t = Time.now
      # shared numbers an edition does not read, per system, from the edition files counting.json lists
      missing = JSON.parse(counting.read)['systems'].filter_map do |slug, sys|
        files = sys['editions'].map { |e| UPSTREAM_TEXT.join('mushaf', "#{e['mushaf']}.json") }.select(&:exist?)
        next if files.empty? # no edition file: nothing known about its words

        [slug, files.flat_map { |f| JSON.parse(f.read)['numbering']['missing'] }.to_set]
      end.to_h
      r = Qiraat::Import::Numberings.new(counting_path: counting, catalog_path: catalog, systems: systems, dry_run: dry, missing: missing,
                                         source: "quran-text counting.json @#{YAML.safe_load(Rails.root.join('config/qiraat_sources.yml').read)['sources']['quran-text']['ref'][0, 7]}").call
      puts "numberings#{dry ? ' (DRY RUN)' : ''} in #{(Time.now - t).round(1)}s"
      r.each { |slug, s| puts format('  %-13s ayahs=%-5d rows=%-5d unanchored=%-3d %s', slug, s[:ayahs], s[:rows], s[:unanchored], s[:relations].sort.map { |k, v| "#{k}=#{v}" }.join(' ')) }
    end

    desc 'Printed numberings for editions that deviate from their madhhab, and default numberings per riwayah (P4.3)'
    task printed_numberings: :environment do
      dry = ENV['DRY_RUN'].present?
      r = Qiraat::Import::PrintedNumberings.new(mushaf_dir: UPSTREAM_TEXT.join('mushaf'), counting_path: UPSTREAM_TEXT.join('counting.json'), catalog_path: UPSTREAM_TEXT.join('catalog.json'), dry_run: dry).call
      puts "printed numberings#{dry ? ' (DRY RUN)' : ''}"
      r[:editions].each { |k, e| puts format('  %-7s printed=%-5d madhhab=%-13s %s', k, e[:printed], e[:system], e[:deviates] ? "DEVIATES by #{e[:distance]} -> #{e[:numbering]}" : 'equal') }
      r[:defaults].each { |slug, n| puts format('  default %-14s -> %s', slug, n) }
    end

    desc 'Precompute ayah_mappings (Kufi verse -> ayah per numbering) (P4.3)'
    task ayah_mappings: :environment do
      dry = ENV['DRY_RUN'].present?
      r = Qiraat::Import::AyahMappings.new(dry_run: dry).call
      puts "ayah_mappings#{dry ? ' (DRY RUN)' : ''}"
      r.each { |slug, s| puts format('  %-18s rows=%-5d splits=%-4d merges_with_next=%-4d %s', slug, s[:rows], s[:splits], s[:merges_with_next], s[:relations].sort.map { |k, v| "#{k}=#{v}" }.join(' ')) }
    end

    desc 'Fill ayah_texts for row-backed scripts from word_texts (P4.3)'
    task ayah_texts: :environment do
      dry = ENV['DRY_RUN'].present?
      r = Qiraat::Import::AyahTexts.new(dry_run: dry).call
      puts "ayah_texts#{dry ? ' (DRY RUN)' : ''}"
      r.each { |slug, s| puts format('  %-16s %s', slug, s[:error] || "numbering=#{s[:numbering]} ayahs=#{s[:ayahs]} empty=#{s[:empty]}") }
    end

    desc 'Import quran-text differences.json (+ the dotting variants of word-index.csv) into word_differences'
    task word_differences: :environment do
      path = UPSTREAM_TEXT.join('differences.json')
      index = UPSTREAM_TEXT.join('word-index.csv')
      abort "#{path} missing; run rake qiraat:fetch" unless path.exist? && index.exist?
      dry = ENV['DRY_RUN'].present?
      r = Qiraat::Import::WordDifferences.new(path: path, word_index_path: index, dry_run: dry).call
      puts "word_differences#{dry ? ' (DRY RUN)' : ''}: in file #{r[:in_file]}, rows #{r[:rows]}, merged onto one QUL row #{r[:merged].inspect}, unmapped #{r[:unmapped].inspect}, deleted #{r[:deleted]}"
      r[:by_status].sort.each { |st, n| puts format('  %-16s %d', st, n) }
      abort('unmapped numbers') if r[:unmapped].any?
    end
  end

  namespace :verify do
    desc 'Verify the madhhab numberings against counting.json, catalog surah counts and the Kufi verses (P4.2)'
    task numberings: :environment do
      counting = JSON.parse(Rails.root.join('tmp', 'qiraat', 'upstream', 'quran-text', 'data', 'counting.json').read)
      catalog = JSON.parse(Rails.root.join('tmp', 'qiraat', 'upstream', 'quran-text', 'data', 'catalog.json').read)
      failed = []
      check = lambda do |name, actual, expected|
        ok = actual == expected
        failed << name unless ok
        puts format('  %-56s %s %s', name, ok ? 'OK ' : 'FAIL', ok ? actual.inspect : "#{actual.inspect} expected #{expected.inspect}")
      end
      counting['systems'].each do |slug, sys|
        n = AyahNumbering.find_by(slug: slug)
        next check.call("#{slug} present", false, true) unless n

        check.call("#{slug}: counted ayahs = ayah_ends", n.numbered_ayahs.counted.count, sys['ayah_ends'].size)
        check.call("#{slug}: total_ayahs = reference_total", n.total_ayahs, sys['reference_total'])
        check.call("#{slug}: every counted ayah anchored", n.numbered_ayahs.counted.where(kufi_first_verse_id: nil).count, 0)
        check.call("#{slug}: ayah_index dense", n.numbered_ayahs.counted.maximum(:ayah_index), sys['ayah_ends'].size)
        edition = catalog['riwayahs'].find { |r| r['counting_system'] == slug && r['ayah_count'] == sys['reference_total'] }
        if edition
          per_surah = catalog['surahs'].to_h { |s| [Chapter.find_by(chapter_number: s['number']).id, s['ayah_count'][edition['key']]] }
          check.call("#{slug}: per-surah counts = catalog (#{edition['key']})", n.surah_counts, per_surah)
        end
      end
      kufi = AyahNumbering.find_by(slug: 'kufi')
      if kufi
        check.call('kufi: rows take the verse ids', kufi.numbered_ayahs.where('id <> kufi_first_verse_id').count, 0)
        check.call('kufi: all same', kufi.numbered_ayahs.where.not(relation: 'same').count, 0)
        check.call('kufi: 6236 rows', kufi.numbered_ayahs.count, Verse.count)
      end
      ml = AyahNumbering.find_by(slug: 'madani-last')
      if ml
        check.call('madani-last 1:0 unnumbered basmalah', ml.ayah(1, 0)&.relation, 'unnumbered')
        check.call('madani-last 2:1 merges Kufi 2:1-2:2', ml.ayah(2, 1)&.kufi_verses&.map(&:verse_key), %w[2:1 2:2])
        check.call('madani-last 1:6 and 1:7 split Kufi 1:7', [ml.ayah(1, 6)&.relation, ml.ayah(1, 7)&.relation], %w[split split])
      end
      abort("#{failed.size} check(s) failed") if failed.any?
      puts 'numberings OK'
    end

    desc 'Verify printed numberings, ayah_mappings and ayah_texts against quran-text ayah-map.json and the catalog (P4.3)'
    task ayah_mappings: :environment do
      ayah_map = JSON.parse(Rails.root.join('tmp', 'qiraat', 'upstream', 'quran-text', 'data', 'ayah-map.json').read)
      catalog = JSON.parse(Rails.root.join('tmp', 'qiraat', 'upstream', 'quran-text', 'data', 'catalog.json').read)
      failed = []
      check = lambda do |name, actual, expected|
        ok = actual == expected
        failed << name unless ok
        puts format('  %-60s %s %s', name, ok ? 'OK ' : 'FAIL', ok ? actual.inspect : "#{actual.inspect} expected #{expected.inspect}")
      end
      # relation counts per edition from ayah-map.json vs the mapping of the riwayah's default numbering
      catalog['riwayahs'].each do |r|
        riwayah = Riwayah.find_by(slug: r['key'] == 'shubah' ? 'shuba' : r['key'])
        numbering = riwayah&.default_numbering
        next check.call("#{r['key']}: riwayah has a default numbering", false, true) unless numbering

        check.call("#{r['key']}: default numbering total = catalog ayah_count", numbering.total_ayahs, r['ayah_count'])
        expected = ayah_map['ayahs'].group_by { |e| e[r['key']]['relation'] }.transform_values(&:size)
        actual = AyahMapping.where(numbering_id: numbering.id).group(:relation).count
        check.call("#{r['key']}: relation counts = ayah-map.json (#{numbering.slug})", actual.sort.to_h, expected.sort.to_h)
        # spot-check every 97th Kufi verse against the map
        bad = 0
        ayah_map['ayahs'].each_with_index do |e, i|
          next unless (i % 97).zero?

          v = Verse.find_by(verse_key: "#{e['surah']}:#{e['ayah']}")
          m = AyahMapping.find_by(numbering_id: numbering.id, verse_id: v.id)
          target = e[r['key']]
          bad += 1 unless m && m.ayah.ayah_number == target['ayah'] && (target['ayah_last'].nil? || m.ayah_last&.ayah_number == target['ayah_last'])
        end
        check.call("#{r['key']}: sampled targets equal ayah-map.json", bad, 0)
      end
      Script.row_backed.each do |s|
        n = s.riwayah.default_numbering
        check.call("ayah_texts #{s.slug}: one row per ayah of #{n.slug}", AyahText.where(script_id: s.id).count, n.numbered_ayahs.count)
      end
      warsh = Script.find_by(slug: 'qpc-warsh')
      if warsh
        ml = warsh.riwayah.default_numbering
        check.call('warsh ayah 0 (basmalah) text present', AyahText.find_by(script_id: warsh.id, ayah_id: ml.ayah(1, 0).id)&.text&.split&.size, 4)
        check.call('warsh 1:1 text starts with al-hamd form', AyahText.find_by(script_id: warsh.id, ayah_id: ml.ayah(1, 1).id)&.text&.split&.first, WordText.find_by(script_id: warsh.id, word_id: Word.unscoped.find_by(location: '1:2:1').id)&.text)
      end
      abort("#{failed.size} check(s) failed") if failed.any?
      puts 'ayah_mappings OK'
    end

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
      dotting = CSV.foreach(Rails.root.join('tmp', 'qiraat', 'upstream', 'quran-text', 'data', 'word-index.csv'), headers: true).count { |r| r['status'] == 'dotting_variant' }
      check.call('rows = file entries - merged pair + dotting variants', WordDifference.count, data['count'] - 1 + dotting)
      by_status.each { |st, n| check.call("status #{st}", WordDifference.where(status: st).count, st == 'word_boundary' ? n - 1 : n) }
      check.call('status dotting_variant (word-index.csv)', WordDifference.where(status: 'dotting_variant').count, dotting)
      malik = WordDifference.find_by(word_id: Word.unscoped.find_by(location: '1:4:1')&.id)
      check.call('1:4:1 (malik/maalik) riwayat per spelling', malik&.spelling_groups&.map { |_t, s| s.sort }, [%w[hafs shuba], %w[bazzi duri qalun warsh], ['susi']])
      check.call('1:4:1 Warsh form is the Warsh word_texts form', malik&.form_for('warsh'), Word.unscoped.find_by(location: '1:4:1')&.text_for(Script.find_by(slug: 'qpc-warsh')))
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
