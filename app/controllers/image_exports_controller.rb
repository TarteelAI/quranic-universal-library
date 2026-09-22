# frozen_string_literal: true

class ImageExportsController < ApplicationController
  protect_from_forgery except: [:batch_export, :verse_words]

  SCRIPT_TYPES = [
    { id: 'code_v1', name: 'QPC Hafs V1 (code_v1)' },
    { id: 'code_v2', name: 'QPC Hafs V2 (code_v2)' },
    { id: 'code_v4', name: 'QPC Hafs V4 (code_v4)' },
    { id: 'text_qpc_hafs', name: 'QPC Hafs Unicode (text_qpc_hafs)' },
    { id: 'text_uthmani_tajweed', name: 'Uthmani Tajweed (text_uthmani_tajweed)' },
    { id: 'text_qpc_nastaleeq_hafs', name: 'QPC Nastaleeq (text_qpc_nastaleeq_hafs)' },
    { id: 'text_indopak_nastaleeq', name: 'Indopak Nastaleeq (text_indopak_nastaleeq)' },
    { id: 'text_digital_khatt', name: 'Digital Khatt (text_digital_khatt)' }
  ].freeze

  def show
    @mushafs = Mushaf.approved.order(:id)
    @chapters = Chapter.order(:chapter_number).map do |c|
      [
        "#{c.chapter_number}. #{c.name_simple} (#{c.name_arabic})",
        c.chapter_number,
        { 'data-verses' => c.verses_count }
      ]
    end
    @scripts = SCRIPT_TYPES

    # Initial defaults
    @default_mushaf = @mushafs.first || Mushaf.find_by(id: 1)
    @default_chapter = 1
    @default_verse = 1
    @default_word = 1
    @default_script = 'code_v1'
    @default_font_size = 50
    @default_page = 1
  end

  def download
    export_type = params[:export_type].presence || 'mushaf_page'
    format = params[:format] == 'webp' ? 'webp' : 'png'
    scale = params[:scale].presence || '2'
    transparent = params[:transparent] == 'true' ? 'true' : 'false'
    filename = params[:filename].presence || "quran_export_#{Time.current.to_i}"

    # Render target export view directly to HTML string
    html_content = case export_type
                   when 'mushaf_page'
                     page_num = (params[:page_number] || 1).to_i
                     @mushaf = Mushaf.find_by(id: params[:mushaf_id]) || Mushaf.first
                     @words = MushafWord.where(mushaf_id: @mushaf.id, page_number: page_num).order('position_in_page ASC')
                     render_to_string(
                       template: 'exports/mushaf_page',
                       layout: 'export',
                       formats: [:html],
                       assigns: { mushaf: @mushaf, words: @words, page_number: page_num, resource: @mushaf&.resource_content }
                     )
                   when 'ayah'
                     verse_param = params[:ayah].to_s.presence || '1:1'
                     @verse = if verse_param.include?(':')
                                Verse.find_by(verse_key: verse_param)
                              else
                                Verse.find_by(verse_index: verse_param)
                              end
                     render_to_string(
                       template: 'exports/ayah',
                       layout: 'export',
                       formats: [:html],
                       assigns: { verse: @verse }
                     )
                   when 'word'
                     word_param = params[:word].to_s.presence || '1:1:1'
                     @word = if word_param.include?(':')
                               Word.find_by(location: word_param)
                             else
                               Word.find_by(word_index: word_param)
                             end
                     render_to_string(
                       template: 'exports/word',
                       layout: 'export',
                       formats: [:html],
                       assigns: { word: @word }
                     )
                   end

    # Inline compiled export.css into the HTML so Puppeteer does not need HTTP roundtrips
    compiled_css = compile_export_css
    html_content = html_content.gsub(/<link[^>]*href="[^"]*export[^"]*"[^>]*>/, "<style>#{compiled_css}</style>")

    temp_html = Rails.root.join('tmp', 'exports', "#{filename}_#{SecureRandom.hex(4)}.html")
    temp_img = Rails.root.join('tmp', 'exports', "#{filename}_#{SecureRandom.hex(4)}.#{format}")
    FileUtils.mkdir_p(File.dirname(temp_html))

    File.write(temp_html, html_content)

    cmd = "node #{Rails.root.join('scripts', 'screenshot_helper.js')} #{Shellwords.escape(temp_html.to_s)} #{Shellwords.escape(temp_img.to_s)} #{format} #{scale} #{transparent}"
    system(cmd)

    FileUtils.rm_f(temp_html)

    if File.exist?(temp_img)
      send_file temp_img,
                filename: "#{filename}.#{format}",
                type: format == 'webp' ? 'image/webp' : 'image/png',
                disposition: 'attachment'
    else
      render plain: "Failed to render image with Headless Chrome", status: :internal_server_error
    end
  end

  def verse_words
    verse_key = params[:verse_key]
    if verse_key.blank? && params[:chapter_id].present? && params[:verse_number].present?
      verse_key = "#{params[:chapter_id]}:#{params[:verse_number]}"
    end

    verse = Verse.find_by(verse_key: verse_key) if verse_key.present?
    words_count = verse&.words_count || Word.where(verse_id: verse&.id).count

    render json: {
      verse_key: verse_key,
      words_count: [words_count, 1].max
    }
  end

  def batch_export
    export_type = params[:export_type] # 'mushaf_page', 'ayah', 'word'
    format = params[:format] == 'webp' ? 'webp' : 'png'
    script = params[:script].presence || 'code_v1'
    font_size = params[:font_size].presence || '50'
    scale = params[:scale].presence || '2'
    transparent = params[:transparent] == 'true' ? 'true' : 'false'

    batch_token = "batch_#{Time.current.to_i}_#{SecureRandom.hex(3)}"
    batch_dir = Rails.root.join('tmp', 'exports', batch_token)
    zip_file = Rails.root.join('tmp', 'exports', "#{batch_token}.zip")
    compiled_css = compile_export_css

    FileUtils.mkdir_p(batch_dir)

    case export_type
    when 'mushaf_page'
      mushaf_id = params[:mushaf_id].to_i
      mushaf = Mushaf.find_by(id: mushaf_id) || Mushaf.first
      p1 = [params[:from_page].to_i, 1].max
      p2 = [params[:to_page].to_i, 1].max
      from_page = [p1, p2].min
      to_page = [p1, p2].max
      # Limit batch size to prevent server timeout
      to_page = [to_page, from_page + 20].min

      pages_dir = batch_dir.join('pages')
      FileUtils.mkdir_p(pages_dir)

      (from_page..to_page).each do |page_num|
        words = MushafWord.where(mushaf_id: mushaf.id, page_number: page_num).order('position_in_page ASC')
        params[:page_number] = page_num
        html = render_to_string(
          template: 'exports/mushaf_page',
          layout: 'export',
          formats: [:html],
          assigns: { mushaf: mushaf, words: words, page_number: page_num, resource: mushaf&.resource_content }
        )
        html = html.gsub(/<link[^>]*href="[^"]*export[^"]*"[^>]*>/, "<style>#{compiled_css}</style>")
        
        temp_html = batch_dir.join("temp_#{page_num}.html")
        out_img = pages_dir.join("page_#{page_num.to_s.rjust(3, '0')}.#{format}")
        File.write(temp_html, html)
        system("node #{Rails.root.join('scripts', 'screenshot_helper.js')} #{Shellwords.escape(temp_html.to_s)} #{Shellwords.escape(out_img.to_s)} #{format} #{scale} #{transparent}")
        FileUtils.rm_f(temp_html)
      end

    when 'ayah'
      chapter_id = params[:chapter_id].to_i
      from_ayah = [params[:from_ayah].to_i, 1].max
      to_ayah = params[:to_ayah].to_i
      to_ayah = from_ayah if to_ayah < from_ayah
      # Limit batch size
      to_ayah = [to_ayah, from_ayah + 50].min

      surah_dir = batch_dir.join("surah_#{chapter_id.to_s.rjust(3, '0')}")
      FileUtils.mkdir_p(surah_dir)

      (from_ayah..to_ayah).each do |ayah_num|
        verse = Verse.find_by(verse_key: "#{chapter_id}:#{ayah_num}")
        next unless verse

        params[:script] = script
        params[:font_size] = font_size
        params[:transparent] = transparent

        html = render_to_string(
          template: 'exports/ayah',
          layout: 'export',
          formats: [:html],
          assigns: { verse: verse }
        )
        html = html.gsub(/<link[^>]*href="[^"]*export[^"]*"[^>]*>/, "<style>#{compiled_css}</style>")

        temp_html = batch_dir.join("temp_ayah_#{ayah_num}.html")
        out_img = surah_dir.join("ayah_#{ayah_num.to_s.rjust(3, '0')}.#{format}")
        File.write(temp_html, html)
        system("node #{Rails.root.join('scripts', 'screenshot_helper.js')} #{Shellwords.escape(temp_html.to_s)} #{Shellwords.escape(out_img.to_s)} #{format} #{scale} #{transparent}")
        FileUtils.rm_f(temp_html)
      end

    when 'word'
      chapter_id = params[:chapter_id].to_i
      verse_num = params[:verse_num].to_i
      from_word = [params[:from_word].to_i, 1].max
      to_word = params[:to_word].to_i
      to_word = from_word if to_word < from_word
      to_word = [to_word, from_word + 50].min

      words_dir = batch_dir.join("surah_#{chapter_id.to_s.rjust(3, '0')}_ayah_#{verse_num.to_s.rjust(3, '0')}")
      FileUtils.mkdir_p(words_dir)

      (from_word..to_word).each do |word_num|
        word = Word.find_by(location: "#{chapter_id}:#{verse_num}:#{word_num}")
        next unless word

        params[:script] = script
        params[:font_size] = font_size
        params[:transparent] = transparent

        html = render_to_string(
          template: 'exports/word',
          layout: 'export',
          formats: [:html],
          assigns: { word: word }
        )
        html = html.gsub(/<link[^>]*href="[^"]*export[^"]*"[^>]*>/, "<style>#{compiled_css}</style>")

        temp_html = batch_dir.join("temp_word_#{word_num}.html")
        out_img = words_dir.join("word_#{word_num.to_s.rjust(3, '0')}.#{format}")
        File.write(temp_html, html)
        system("node #{Rails.root.join('scripts', 'screenshot_helper.js')} #{Shellwords.escape(temp_html.to_s)} #{Shellwords.escape(out_img.to_s)} #{format} #{scale} #{transparent}")
        FileUtils.rm_f(temp_html)
      end
    end

    # Compress batch directory into ZIP
    system("cd #{Shellwords.escape(batch_dir.to_s)} && zip -r #{Shellwords.escape(zip_file.to_s)} .")
    FileUtils.rm_rf(batch_dir)

    if File.exist?(zip_file)
      send_file zip_file,
                filename: "quran_export_#{export_type}_#{Time.current.to_i}.zip",
                type: 'application/zip',
                disposition: 'attachment'
    else
      render json: { success: false, error: 'Failed to create ZIP package' }, status: :internal_server_error
    end
  end

  private

  def compile_export_css
    env = Rails.application.assets || Sprockets::Railtie.build_environment(Rails.application)
    env['export.css']&.to_s || ''
  end
end
