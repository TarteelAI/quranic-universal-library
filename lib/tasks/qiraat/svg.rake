# frozen_string_literal: true

# quran-svg ayah polygons as the second witness for a generated layout (P5.6).
#
#   rake qiraat:svg:fetch                 sparse clone of the per-page JSON for the
#                                         five traced editions, pinned to the commit
#                                         in config/qiraat_sources.yml (quran-svg)
#   rake qiraat:verify:svg_layout[warsh]  diff the generated mushaf against the
#                                         polygons: ayah order and lines per page;
#                                         review file tmp/qiraat/svg-diff-<key>.json;
#                                         with zero mismatches the mushaf is marked
#                                         layout_source = svg-verified
#   PAGES=1,2,50      check only these pages
require_relative '../../qiraat/layout/svg_diff'

namespace :qiraat do
  namespace :svg do
    SVG_DIR = Rails.root.join('tmp', 'qiraat', 'upstream', 'quran-svg')

    def svg_source
      YAML.safe_load(Rails.root.join('config', 'qiraat_sources.yml').read).dig('sources', 'quran-svg') or abort 'config/qiraat_sources.yml has no quran-svg entry'
    end

    desc 'Fetch the quran-svg per-page polygon JSON (sparse clone at the pinned commit)'
    task fetch: :environment do
      src = svg_source
      paths = Qiraat::Layout::SvgDiff::EDITIONS.values.map { |r| "mushafs/#{r}/kfqc/json" }
      if SVG_DIR.join('.git').exist?
        sha = `git -C #{SVG_DIR} rev-parse HEAD`.strip
        if sha == src['ref']
          puts "  quran-svg already at #{sha[0, 12]}"
          next
        end
        FileUtils.rm_rf(SVG_DIR)
      end
      FileUtils.mkdir_p(SVG_DIR.dirname)
      system('git', 'clone', '-q', '--filter=blob:none', '--sparse', '--no-checkout', src['repo'], SVG_DIR.to_s) or abort 'clone failed'
      system('git', '-C', SVG_DIR.to_s, 'sparse-checkout', 'set', *paths) or abort 'sparse-checkout failed'
      system('git', '-C', SVG_DIR.to_s, 'checkout', '-q', src['ref']) or abort "checkout of #{src['ref']} failed"
      paths.each { |p| puts "  #{p}: #{Dir[SVG_DIR.join(p, '*.json')].size} files" }
      puts "  quran-svg at #{src['ref'][0, 12]} (#{src['ref_date']})"
    end
  end

  namespace :verify do
    desc 'Diff a generated layout against the quran-svg polygons: rake qiraat:verify:svg_layout[warsh]'
    task :svg_layout, [:key] => :environment do |_, args|
      key = args[:key] or abort 'usage: rake qiraat:verify:svg_layout[warsh]'
      folder = Qiraat::Layout::SvgDiff::EDITIONS[key] or abort "quran-svg has no polygons for #{key} (Susi and Bazzi are reviewed by hand)"
      dir = Rails.root.join('tmp', 'qiraat', 'upstream', 'quran-svg', 'mushafs', folder, 'kfqc', 'json')
      abort "#{dir} missing: run rake qiraat:svg:fetch" unless dir.exist?
      slug, = Qiraat::Import::ScriptText::EDITIONS.fetch(key)
      script = Script.find_by(slug: slug) || (key == 'hafs' ? Script.find_by!(slug: 'qpc-hafs') : abort("script #{slug} missing"))
      mushaf = Mushaf.find_by(script_id: script.id, layout_source: Mushaf::GENERATED_LAYOUT_SOURCES) || (key == 'hafs' ? Mushaf.find(5) : abort("no generated mushaf for #{key}"))
      pages = ENV['PAGES'].presence&.split(',')&.map(&:to_i)
      t = Time.now
      r = Qiraat::Layout::SvgDiff.new(key: key, json_dir: dir, mushaf: mushaf, pages: pages).call
      out = Rails.root.join('tmp', 'qiraat', "svg-diff-#{key}.json")
      out.write(JSON.pretty_generate(r.merge(checked_at: Time.now.utc.iso8601, quran_svg_ref: `git -C #{dir} rev-parse HEAD`.strip)))
      r[:mismatches].first(25).each { |m| puts "    page #{m[:page]} #{m[:kind]} #{m[:ayah]}: svg #{m[:svg].inspect} generated #{m[:generated].inspect}" }
      puts "    ... #{r[:mismatches].size - 25} more" if r[:mismatches].size > 25
      puts "  review: #{out} (#{(Time.now - t).round(1)}s)"
      if r[:mismatches].empty? && pages.nil? && mushaf.layout_source == 'generated'
        mushaf.update_columns(layout_source: 'svg-verified')
        puts "  mushaf #{mushaf.id} (#{mushaf.name}) marked svg-verified"
      end
      exit(1) unless r[:mismatches].empty?
    end
  end
end
