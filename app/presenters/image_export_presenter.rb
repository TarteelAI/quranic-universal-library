# frozen_string_literal: true

class ImageExportPresenter < ApplicationPresenter
  DEFAULT_CHAPTER = 1
  DEFAULT_VERSE = 1
  DEFAULT_WORD = 1
  DEFAULT_SCRIPT = 'code_v1'
  DEFAULT_FONT_SIZE = 50
  DEFAULT_PAGE = 1

  def mushafs
    @mushafs ||= Mushaf.approved.order(:id)
  end

  def chapters
    @chapters ||= Chapter.order(:chapter_number).map do |c|
      [
        "#{c.chapter_number}. #{c.name_simple} (#{c.name_arabic})",
        c.chapter_number,
        { 'data-verses' => c.verses_count }
      ]
    end
  end

  def scripts
    @scripts ||= begin
      sample_word = Word.first
      QuranScriptsComparisonPresenter::SCRIPT_DISPLAY_NAMES.each_with_object([]) do |(id, name), list|
        if sample_word.respond_to?(id)
          list << { id: id, name: "#{name} (#{id})" }
        end
      end
    end
  end

  def default_mushaf
    @default_mushaf ||= mushafs.first || Mushaf.find_by(id: 1)
  end

  def default_chapter
    params[:chapter].presence&.to_i || DEFAULT_CHAPTER
  end

  def default_verse
    params[:verse].presence&.to_i || DEFAULT_VERSE
  end

  def default_word
    params[:word].presence&.to_i || DEFAULT_WORD
  end

  def default_script
    params[:script].presence || DEFAULT_SCRIPT
  end

  def default_font_size
    params[:font_size].presence&.to_i || DEFAULT_FONT_SIZE
  end

  def default_page
    params[:page].presence&.to_i || DEFAULT_PAGE
  end

  def pages_range
    1..(default_mushaf&.pages_count || 604)
  end

  def page_title
    'Export Quran pages, Ayahs, and Words as high-resolution PNG / WEBP images'
  end

  def meta_title
    'Quran Image Export Tool — Render High-Resolution Pages, Ayahs, and Words'
  end

  def meta_description
    'Download and export high-resolution PNG and WEBP images for any Quran page, ayah, or word with custom Quranic scripts, retina scaling, and transparent backgrounds.'
  end
end
