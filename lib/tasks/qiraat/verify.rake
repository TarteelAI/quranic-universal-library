# Verification harness for the multi-riwayah work.
#
#   rake qiraat:verify:baseline            # first run writes tmp/qiraat/baseline.json,
#                                          # later runs compare and exit 1 on any change
#   FORCE=1 rake qiraat:verify:baseline    # overwrite the stored snapshot
#   rake qiraat:verify:render              # same idea for rendered HTML of the smoke pages
#   rake qiraat:verify:render[5,3]         # add one mushaf page (mushaf 5, page 3) to the set
#   FORCE=1 rake qiraat:verify:render      # overwrite the stored render digests
#
# The render check signs in as the local seed admin (db/seed.rb) through a
# Rails integration session, so it needs no running server. Pages are
# normalised before digesting (CSRF tokens, asset fingerprints, timestamps).
# On a mismatch the normalised HTML of both sides is written to
# tmp/qiraat/render/<key>.{stored,current}.html for diffing.
require 'digest'
require 'fileutils'
require 'json'

namespace :qiraat do
  namespace :verify do
    RENDER_PATH = Rails.root.join('tmp', 'qiraat', 'render.json')
    RENDER_DIR = Rails.root.join('tmp', 'qiraat', 'render')
    SEED_ADMIN = 'admin@cms.com'

    # The smoke set: one public mushaf page, the word-by-word tool, a CMS verse
    # page and the CMS mushaf page preview. Keys are stable across runs.
    def qiraat_smoke_pages
      wbw = ResourceContent.translations.one_word.approved.order(:id).first
      {
        'mushaf_5_page_1' => '/mushaf_layouts/5?page_number=1',
        'mushaf_5_page_604' => '/mushaf_layouts/5?page_number=604',
        'wbw_1_1' => "/word_translations/new?resource_id=#{wbw&.id}&ayah=1:1",
        'cms_verse_1' => '/cms/verses/1',
        'cms_mushaf_page_preview' => '/cms/mushaf_page_preview?mushaf=5&page=1'
      }
    end

    def qiraat_normalise_html(html)
      html
        .gsub(/name="authenticity_token" value="[^"]*"/, 'name="authenticity_token" value="X"')
        .gsub(/<meta name="csrf-token" content="[^"]*"/, '<meta name="csrf-token" content="X"')
        .gsub(/-[0-9a-f]{20,64}\.(css|js|woff2?|ttf|png|svg)/, '-FINGERPRINT.\1')
        .gsub(/\?v=\d+/, '?v=V')
        .gsub(/\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2})?( UTC)?/, 'TIMESTAMP')
        .gsub(/\s+/, ' ')
        .strip
    end

    def qiraat_render_session
      require 'warden'
      require 'rails/test_help' unless defined?(ActionDispatch::Integration::Session)
      Warden.test_mode!
      user = User.find_by!(email: SEED_ADMIN)
      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.host! 'localhost'
      Warden.on_next_request { |proxy| proxy.set_user(user, scope: :user) }
      session
    end

    def qiraat_render_all(pages)
      session = qiraat_render_session
      pages.each_with_object({}) do |(key, path), out|
        Warden.on_next_request { |proxy| proxy.set_user(User.find_by!(email: SEED_ADMIN), scope: :user) }
        session.get(path)
        body = session.response.body.to_s
        html = qiraat_normalise_html(body)
        out[key] = { 'path' => path, 'status' => session.response.status, 'bytes' => html.bytesize, 'sha256' => Digest::SHA256.hexdigest(html), 'html' => html }
      end
    ensure
      Warden.test_reset! if defined?(Warden)
    end

    desc 'Snapshot (first run) or verify (later runs) digests of the Hafs data'
    task baseline: :environment do
      baseline = Qiraat::Baseline.new
      t = Time.now
      current = baseline.compute
      puts "computed in #{(Time.now - t).round(1)}s on #{current['database']}"
      if !baseline.exists? || ENV['FORCE']
        baseline.write!(current)
        puts "wrote #{baseline.path}"
        current.each { |k, v| puts "  #{k}: #{v.size} entries" if v.is_a?(Hash) }
      else
        diffs = baseline.compare(current)
        if diffs.empty?
          puts "baseline OK: #{(current.keys - %w[generated_at database]).size} sections unchanged (stored #{baseline.read['generated_at']})"
        else
          puts 'BASELINE CHANGED:'
          diffs.each { |d| puts "  #{d}" }
          abort("#{diffs.size} difference(s)")
        end
      end
    end

    desc 'Snapshot or verify normalised HTML digests of the smoke pages'
    task :render, [:mushaf_id, :page] => :environment do |_t, args|
      pages = qiraat_smoke_pages
      pages["mushaf_#{args[:mushaf_id]}_page_#{args[:page]}"] = "/mushaf_layouts/#{args[:mushaf_id]}?page_number=#{args[:page]}" if args[:mushaf_id]
      current = qiraat_render_all(pages)
      FileUtils.mkdir_p(RENDER_DIR)
      current.each do |key, v|
        abort("#{key} #{v['path']} returned HTTP #{v['status']}") unless v['status'] == 200
        abort("#{key} #{v['path']} rendered the sign-in page") if v['html'].include?('user[password]')
      end
      if !RENDER_PATH.exist? || ENV['FORCE']
        RENDER_PATH.write(JSON.pretty_generate(current.transform_values { |v| v.except('html') }))
        current.each { |k, v| RENDER_DIR.join("#{k}.stored.html").write(v['html']) }
        puts "wrote #{RENDER_PATH} (#{current.size} pages)"
        current.each { |k, v| puts "  #{k}: #{v['bytes']} bytes #{v['sha256'][0, 12]}" }
      else
        stored = JSON.parse(RENDER_PATH.read)
        diffs = []
        current.each do |k, v|
          s = stored[k]
          next diffs << "#{k}: no stored digest (run with FORCE=1 to add it)" unless s
          next if s['sha256'] == v['sha256']
          RENDER_DIR.join("#{k}.current.html").write(v['html'])
          diffs << "#{k}: changed (#{s['bytes']} -> #{v['bytes']} bytes); diff #{RENDER_DIR}/#{k}.stored.html #{RENDER_DIR}/#{k}.current.html"
        end
        if diffs.empty?
          puts "render OK: #{current.size} pages identical"
        else
          puts 'RENDER CHANGED:'
          diffs.each { |d| puts "  #{d}" }
          abort("#{diffs.size} page(s) differ")
        end
      end
    end
  end
end
