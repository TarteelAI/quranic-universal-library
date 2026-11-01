# frozen_string_literal: true

class ImageExportsController < ApplicationController
  before_action :require_login_for_export, only: %i[download batch_export]
  before_action :remember_return_location, only: :show

  before_action :init_presenter, only: :show

  def show
  end

  def download
    export_type = params[:export_type].presence || 'mushaf_page'
    format = params[:format] == 'webp' ? 'webp' : 'png'
    scale = params[:scale].presence || '2'
    transparent = params[:transparent] == 'true' ? 'true' : 'false'
    filename = params[:filename].presence || "quran_export_#{Time.current.to_i}"

    html_content = render_export_html(export_type)

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
        params[:page_number] = page_num
        html = render_export_html('mushaf_page', mushaf_id: mushaf.id, page_number: page_num)

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
        verse_key = "#{chapter_id}:#{ayah_num}"
        params[:ayah] = verse_key
        params[:script] = script
        params[:font_size] = font_size
        params[:transparent] = transparent

        html = render_export_html('ayah', ayah: verse_key)
        next unless html

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
        word_loc = "#{chapter_id}:#{verse_num}:#{word_num}"
        params[:word] = word_loc
        params[:script] = script
        params[:font_size] = font_size
        params[:transparent] = transparent

        html = render_export_html('word', word: word_loc)
        next unless html

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

  def render_export_html(export_type, overrides = {})
    case export_type
    when 'mushaf_page'
      page_num = (overrides[:page_number] || params[:page_number] || 1).to_i
      mushaf_id = overrides[:mushaf_id] || params[:mushaf_id]
      mushaf = Mushaf.find_by(id: mushaf_id) || Mushaf.first
      words = MushafWord.where(mushaf_id: mushaf.id, page_number: page_num).order('position_in_page ASC')
      render_to_string(
        template: 'exports/mushaf_page',
        layout: 'image_export',
        formats: [:html],
        assigns: { mushaf: mushaf, words: words, page_number: page_num, resource: mushaf&.resource_content }
      )
    when 'ayah'
      verse_param = (overrides[:ayah] || params[:ayah] || '1:1').to_s
      verse = verse_param.include?(':') ? Verse.find_by(verse_key: verse_param) : Verse.find_by(verse_index: verse_param)
      return nil unless verse

      render_to_string(
        template: 'exports/ayah',
        layout: 'image_export',
        formats: [:html],
        assigns: { verse: verse }
      )
    when 'word'
      word_param = (overrides[:word] || params[:word] || '1:1:1').to_s
      word = word_param.include?(':') ? Word.find_by(location: word_param) : Word.find_by(word_index: word_param)
      return nil unless word

      render_to_string(
        template: 'exports/word',
        layout: 'image_export',
        formats: [:html],
        assigns: { word: word }
      )
    end
  end

  # Anyone can browse and preview; rendering/downloading needs an account.
  # These endpoints are called with fetch(), so answer 401 JSON rather than a
  # redirect and let the JS send the user to the sign-in page.
  def require_login_for_export
    return if user_signed_in?

    render json: {
      success: false,
      error: 'Please sign in to export images.',
      sign_in_url: new_user_session_path
    }, status: :unauthorized
  end

  # After signing in, bring the user back to the export tool.
  def remember_return_location
    store_location_for(:user, request.fullpath) unless user_signed_in?
  end

  def init_presenter
    @presenter = ImageExportPresenter.new(self)
  end
end

