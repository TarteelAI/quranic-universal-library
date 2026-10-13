# frozen_string_literal: true

# Generated mushaf layouts (P5.3).
#
#   rake qiraat:mushaf:generate[warsh]            build (or rebuild) the Warsh 15-line layout
#   DRY_RUN=1 rake qiraat:mushaf:generate[warsh]  report and review file only, nothing written
#   COMPARE=5 rake qiraat:mushaf:generate[hafs]   also diff page/line per word against mushaf 5
#   rake qiraat:mushaf:generate_all               the six non-Hafs editions
#   rake qiraat:verify:mushaf_layout[warsh]       the P5.3 acceptance checks
#
# Inputs are the pinned upstream files (rake qiraat:fetch). The review file
# tmp/qiraat/layout-review-<key>.json lists every ayah whose page or lines
# differ from the Complex CSV.
require_relative '../../qiraat/layout/generator'

namespace :qiraat do
  namespace :mushaf do
    UPSTREAM = Rails.root.join('tmp', 'qiraat', 'upstream')
    GENERATED_EDITIONS = %w[shubah warsh qalun duri susi bazzi].freeze

    def generate_layout(key)
      path = UPSTREAM.join('quran-text', 'data', 'mushaf', "#{key}.json")
      abort "#{path} missing: run rake qiraat:fetch" unless path.exist?
      csv = Qiraat::Layout::Generator::CSV_FILES[key]
      csv_path = csv && UPSTREAM.join('kfgqpc-resources', csv)
      puts "  #{key}: no Complex CSV, cross-check skipped" if csv.nil?
      gen = Qiraat::Layout::Generator.new(
        key: key, path: path, csv_path: csv_path,
        dry_run: ENV['DRY_RUN'].present?,
        compare_mushaf_id: ENV['COMPARE'].presence&.to_i,
        review_path: Rails.root.join('tmp', 'qiraat', "layout-review-#{key}.json")
      )
      t = Time.now
      r = gen.call
      puts "  #{key}: #{r[:stats].map { |k, v| "#{k}=#{v}" }.join(' ')}"
      puts "  #{key}: lines/page #{r[:lines_per_page].inspect}"
      puts "  #{key}: csv #{r[:csv][:agreeing]}/#{r[:csv][:checked]} agree" if r[:csv]
      r[:warnings].each { |w| puts "  #{key}: WARN #{w}" }
      puts "  #{key}: done in #{(Time.now - t).round(1)}s#{r[:dry_run] ? ' (DRY RUN)' : ''}"
      r
    end

    desc 'Generate the 15-line layout of a quran-text edition: rake qiraat:mushaf:generate[warsh]'
    task :generate, [:key] => :environment do |_, args|
      abort 'usage: rake qiraat:mushaf:generate[warsh]' if args[:key].blank?
      generate_layout(args[:key])
    end

    desc 'Generate the layouts of the six non-Hafs editions'
    task generate_all: :environment do
      GENERATED_EDITIONS.each { |key| generate_layout(key) }
    end
  end

  namespace :verify do
    desc 'Verify a generated layout: rake qiraat:verify:mushaf_layout[warsh]'
    task :mushaf_layout, [:key] => :environment do |_, args|
      key = args[:key] or abort 'usage: rake qiraat:verify:mushaf_layout[warsh]'
      slug, = Qiraat::Import::ScriptText::EDITIONS.fetch(key)
      script = Script.find_by(slug: slug) || (key == 'hafs' ? Script.find_by!(slug: 'qpc-hafs') : abort("script #{slug} missing")) # Hafs text is the qpc-hafs column (see Generator)
      mushaf = Mushaf.find_by!(script_id: script.id, layout_source: Mushaf::GENERATED_LAYOUT_SOURCES)
      data = JSON.parse(Rails.root.join('tmp', 'qiraat', 'upstream', 'quran-text', 'data', 'mushaf', "#{key}.json").read)
      review = Rails.root.join('tmp', 'qiraat', "layout-review-#{key}.json")
      review = review.exist? ? JSON.parse(review.read) : {}
      failed = []
      check = lambda do |name, actual, expected|
        ok = actual == expected
        failed << name unless ok
        puts format('  %-62s %s %s', name, ok ? 'OK ' : 'FAIL', ok ? actual.inspect : "#{actual.inspect} expected #{expected.inspect}")
      end
      words = MushafWord.where(mushaf_id: mushaf.id)
      check.call('pages_count', mushaf.pages_count, 604)
      check.call('pages with words', words.distinct.count(:page_number), 604)
      check.call('word rows = printed words', words.where(char_type_name: 'word').count, data['words'].size)
      check.call('markers = counted ayahs', words.where(char_type_name: 'end').count, data['ayah_starts'].size)
      check.call('markers = numbering total', words.where(char_type_name: 'end').count, mushaf.numbering.total_ayahs)
      check.call('rows without an ayah', words.where(ayah_id: nil).count, 0)
      check.call('word rows without a word', words.where(char_type_name: 'word', word_id: nil).count, 0)
      check.call('lines above 15', words.where('line_number > 15').count, 0)
      # contiguity: shared numbers never go backwards in page/position order and page N+1 starts after page N ends
      numbers = words.joins(:word).where(char_type_name: 'word').order(:page_number, :position_in_page).pluck(Arel.sql('mushaf_words.page_number'), Arel.sql('words.number'))
      backwards = numbers.each_cons(2).count { |(_, a), (_, b)| b < a }
      check.call('word numbers never go backwards', backwards, 0)
      page_first = numbers.group_by(&:first).transform_values { |v| [v.first[1], v.last[1]] }
      breaks = (1...604).count { |p| page_first[p + 1] && page_first[p] && page_first[p + 1][0] <= page_first[p][1] }
      check.call('page N+1 starts after page N ends', breaks, 0)
      check.call('surah header lines', MushafLineAlignment.where(mushaf_id: mushaf.id, alignment: 'surah_name').count, 114)
      check.call('basmalah lines', MushafLineAlignment.where(mushaf_id: mushaf.id, alignment: 'bismillah').count, 112)
      check.call('pages with first/last ayah', MushafPage.where(mushaf_id: mushaf.id).where.not(first_ayah_id: nil).where.not(last_ayah_id: nil).count, 604)
      if review['csv']
        n = review['csv']['disagreements'].size
        puts format('  %-62s %s %s', 'csv disagreements under 10', n < 10 ? 'OK ' : 'FAIL', n)
        failed << 'csv' unless n < 10
        review['csv']['disagreements'].each { |d| puts "    #{d['ayah']}: csv #{d['csv']} generated #{d['generated']}" }
      else
        puts '  (no csv cross-check for this edition)'
      end
      puts failed.empty? ? "mushaf_layout[#{key}] OK (mushaf #{mushaf.id})" : "#{failed.size} check(s) failed"
      exit(1) unless failed.empty?
    end
  end
end
