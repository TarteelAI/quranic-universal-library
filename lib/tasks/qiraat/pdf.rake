# frozen_string_literal: true

# Page images of a printed edition for the layout editor's proofreading view (P5.5).
#
#   rake "qiraat:pdf:pages[warsh,/path/to/quran-warsh-mushaf.pdf]"
#
# Renders every PDF page with pdftoppm (poppler) into public/qiraat/pdf/<key>/
# (gitignored) and points the generated mushaf's resource content at them
# ('image-url' / 'image-format'), which the editor's Image View already
# reads, with its zoom and page controls. The PDF's first page is a cover, so
# mushaf page N is image N + 1; the view adds the offset itself. Nothing is
# fetched from the network: Naveed downloads the PDF, this task renders it.
#
#   DPI=60   resolution (default 72: about 900 x 1380 px per page)
#   FIRST=1 LAST=10   a page range for a quick check
namespace :qiraat do
  namespace :pdf do
    desc 'Render a printed edition PDF to page images for the proofreading view: rake "qiraat:pdf:pages[warsh,/path/file.pdf]"'
    task :pages, %i[key pdf] => :environment do |_, args|
      key = args[:key] or abort 'usage: rake "qiraat:pdf:pages[warsh,/path/file.pdf]"'
      pdf = args[:pdf] or abort 'give the PDF path as the second argument'
      abort "#{pdf} not found" unless File.exist?(pdf)
      abort 'pdftoppm (poppler) is not installed' unless system('which pdftoppm > /dev/null 2>&1')
      dir = Rails.root.join('public', 'qiraat', 'pdf', key)
      FileUtils.mkdir_p(dir)
      dpi = (ENV['DPI'] || 72).to_i
      range = []
      range += ['-f', ENV['FIRST']] if ENV['FIRST']
      range += ['-l', ENV['LAST']] if ENV['LAST']
      t = Time.now
      # pdftoppm names files <prefix>-<zero padded n>.jpg; the view wants plain <n>.jpg
      system('pdftoppm', '-r', dpi.to_s, '-jpeg', '-jpegopt', 'quality=80', *range, pdf, dir.join('p').to_s) or abort 'pdftoppm failed'
      renamed = 0
      Dir[dir.join('p-*.jpg')].each do |f|
        n = File.basename(f, '.jpg').delete_prefix('p-').to_i
        FileUtils.mv(f, dir.join("#{n}.jpg"))
        renamed += 1
      end
      puts "  #{renamed} pages rendered to #{dir} in #{(Time.now - t).round}s"

      slug, = Qiraat::Import::ScriptText::EDITIONS.fetch(key)
      mushaf = Mushaf.find_by(script: Script.find_by(slug: slug), layout_source: 'generated')
      if mushaf&.resource_content
        rc = mushaf.resource_content
        rc.meta_data = (rc.meta_data || {}).merge('image-url' => "/qiraat/pdf/#{key}", 'image-format' => 'jpg', 'source-pdf-page-offset' => 1)
        rc.save!(validate: false)
        puts "  mushaf #{mushaf.id} (#{mushaf.name}): proofreading images at /qiraat/pdf/#{key}/<n>.jpg"
      else
        puts "  no generated mushaf for #{key} yet: run rake qiraat:mushaf:generate[#{key}] then this task again"
      end
    end
  end
end
