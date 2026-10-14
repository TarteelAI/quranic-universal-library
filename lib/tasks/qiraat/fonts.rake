# frozen_string_literal: true

# KFGQPC faces for the riwayah scripts (P5.4).
#
#   rake qiraat:fonts:copy    copy the pinned v3.0 TTFs (rake qiraat:fetch) to
#                             public/fonts/qpc (gitignored) and build woff2 next
#                             to them when woff2_compress is installed; the
#                             @font-face rules in _qpc_fonts.scss fall back to
#                             these paths until the CDN has the files
#   rake qiraat:fonts:check   download what the CDN serves for each family and
#                             compare it by sha256 with the pinned release
#
# The fonts stay under KFGQPC terms: never committed, served from the CDN.
require 'digest'
require 'open-uri'

namespace :qiraat do
  namespace :fonts do
    PINNED_DIR = Rails.root.join('tmp', 'qiraat', 'upstream', 'quran-text', 'data', 'fonts')
    DEV_DIR = Rails.root.join('public', 'fonts', 'qpc')
    FONT_CDN = 'https://static-cdn.tarteel.ai/qul/fonts'

    # family => [pinned file, what the CDN serves today, the v3.0 path to upload to]
    FAMILIES = {
      'qpc-hafs' => ['UthmanicHafs-v-3.0.ttf', 'UthmanicHafs_V22.ttf', 'quran_fonts/qpc/uthmanic-hafs-v30.ttf'],
      'qpc-shuba' => ['UthmanicShubah-v-3.0.ttf', 'quran_fonts/qpc/uthmanic-shuba-v20.ttf', 'quran_fonts/qpc/uthmanic-shuba-v30.ttf'],
      'qpc-warsh' => ['UthmanicWarsh-v-3.0.ttf', 'quran_fonts/qpc/uthmanic-warsh-v21.ttf', 'quran_fonts/qpc/uthmanic-warsh-v30.ttf'],
      'qpc-qaloun' => ['UthmanicQaloun-v-3.0.ttf', 'quran_fonts/qpc/uthmanic-qaloun-v21.ttf', 'quran_fonts/qpc/uthmanic-qaloun-v30.ttf'],
      'qpc-douri' => ['UthmanicDouri-V20.ttf', 'quran_fonts/qpc/uthmanic-douri-v20.ttf', 'quran_fonts/qpc/uthmanic-douri-v30.ttf'],
      'qpc-sousi' => ['UthmanicSousi-v-3.0.ttf', 'quran_fonts/qpc/uthmanic-sousi-v20.ttf', 'quran_fonts/qpc/uthmanic-sousi-v30.ttf'],
      'qpc-bazzi' => ['UthmanicBazzi-v-3.0.ttf', nil, 'quran_fonts/qpc/uthmanic-bazzi-v30.ttf']
    }.freeze

    desc 'Write scripts.font_file_url: the CDN file of each riwayah face (v3.0 upload path; Hafs keeps the face it serves today)'
    task urls: :environment do
      Script.where.not(font_family: nil).find_each do |script|
        pinned, current, upload = FAMILIES[script.font_family]
        next unless pinned

        # the riwayah families move to v3.0 (P5.4: Naveed uploads them); qpc-hafs stays on the v2.2 face the layouts were made with
        file = script.font_family == 'qpc-hafs' ? current : upload
        url = "#{FONT_CDN}/#{file}"
        script.update_columns(font_file_url: url) if script.font_file_url != url
        puts format('  %-3d %-14s %s', script.id, script.slug, url)
      end
    end

    desc 'Copy the pinned KFGQPC v3.0 faces to public/fonts/qpc for development (+ woff2)'
    task copy: :environment do
      abort "#{PINNED_DIR} missing: run rake qiraat:fetch" unless PINNED_DIR.exist?
      FileUtils.mkdir_p(DEV_DIR)
      woff2 = system('which woff2_compress > /dev/null 2>&1')
      FAMILIES.each_value do |(pinned, _, _)|
        src = PINNED_DIR.join(pinned)
        FileUtils.cp(src, DEV_DIR.join(pinned))
        system('woff2_compress', DEV_DIR.join(pinned).to_s, out: File::NULL) if woff2
        puts "  #{pinned}#{woff2 ? ' + woff2' : ''}"
      end
      puts "copied to #{DEV_DIR}#{woff2 ? '' : ' (woff2_compress not installed: ttf only)'}"
    end

    desc 'Compare the CDN faces with the pinned KFGQPC releases by sha256'
    task check: :environment do
      puts format('  %-11s %-26s %-10s %-10s %s', 'family', 'pinned', 'pinned', 'cdn', 'cdn file / status')
      FAMILIES.each do |family, (pinned, cdn, upload)|
        want = Digest::SHA256.file(PINNED_DIR.join(pinned)).hexdigest
        status = if cdn.nil?
                   'absent on the CDN'
                 else
                   begin
                     got = Digest::SHA256.hexdigest(URI.parse("#{FONT_CDN}/#{cdn}").read)
                     got == want ? 'same as pinned' : "differs (#{got[0, 10]}): upload #{upload}"
                   rescue StandardError => e
                     "fetch failed: #{e.message[0, 40]}"
                   end
                 end
        puts format('  %-11s %-26s %-10s %-10s %s', family, pinned, want[0, 10], cdn ? File.basename(cdn) : '-', status)
      end
      puts "upload the v3.0 files to #{FONT_CDN}/quran_fonts/qpc/ (ttf + woff2 from rake qiraat:fonts:copy)"
    end
  end
end
