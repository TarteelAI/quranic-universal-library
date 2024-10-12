class WordTextProofreadingsController < CommunityController
  def index
    verses = Verse

    if params[:filter_page].to_i > 0
      verses = verses.where(page_number: params[:filter_page].to_i)
    end

    if params[:filter_juz].to_i > 0
      verses = verses.where(juz_number: params[:filter_juz].to_i)
    end

    if params[:filter_chapter].to_i > 0
      verses = verses.where(chapter_id: params[:filter_chapter].to_i)
    end

    if params[:verse_number].to_i > 0
      verses = verses.where(verse_number: params[:verse_number].to_i)
    end

    order = if params[:sort_order] && params[:sort_order] == 'desc'
              'desc'
            else
              'asc'
            end

    @pagy, @verses = pagy(verses.order("verse_index #{order}"))
  end

  def show
    @verse = Verse.find_by_id_or_key(params[:id])
  end
end