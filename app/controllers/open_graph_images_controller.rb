class OpenGraphImagesController < ApplicationController
  def ayah
    verse = Verse.includes(:chapter).find_by(verse_key: params[:key].to_s)
    return head :not_found unless verse

    path = OpenGraph::ImageService.new(locale: locale_param).ayah_path(verse)
    set_cache_headers
    send_file path, type: 'image/png', disposition: 'inline'
  end

  def surah
    chapter = Chapter.find_by(chapter_number: params[:chapter_number].to_i)
    return head :not_found unless chapter

    path = OpenGraph::ImageService.new(locale: locale_param).surah_path(chapter)
    set_cache_headers
    send_file path, type: 'image/png', disposition: 'inline'
  end

  def word
    chapter_number = params[:chapter_number].presence || params[:chapter].presence
    verse_number = params[:verse_number].presence || params[:ayah].presence
    position = params[:position].presence || params[:word].presence

    if params[:location].present?
      parts = params[:location].to_s.strip.delete_prefix('(').delete_suffix(')').split(':').map(&:to_i)
      chapter_number, verse_number, position = parts.first(3) if parts.size >= 3
    end

    verse = Verse.includes(:chapter).find_by(chapter_id: chapter_number.to_i, verse_number: verse_number.to_i)
    return head :not_found unless verse

    word = verse.words.find_by(position: position.to_i)
    return head :not_found unless word

    path = OpenGraph::ImageService.new(locale: locale_param).word_path(word)
    set_cache_headers
    send_file path, type: 'image/png', disposition: 'inline'
  end

  private

  def set_cache_headers
    response.headers['Cache-Control'] = 'public, max-age=86400'
  end

  def locale_param
    params[:locale].presence || I18n.locale.to_s
  end
end

