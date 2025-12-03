class WordTextProofreadingsController < CommunityController
  ALLOWED_SCRIPTS = [
    'text_qpc_hafs',
    'text_uthmani',
    'text_digital_khatt',
    'text_digital_khatt_v1',
    'text_digital_khatt_indopak',
    'text_indopak_nastaleeq'
  ]

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

  def compare_words
    @char = params[:char].to_s.strip
    script = params[:script].to_s.strip

    if @char.present?
      pattern = "%#{@char}%"
      order = if params[:sort_order] && params[:sort_order] == 'desc'
                'desc'
              else
                'asc'
              end

      if !ALLOWED_SCRIPTS.include?(script)
        script = 'text_qpc_hafs'
      end

      words = Word.unscoped
                  .where("#{script} LIKE ?", pattern)
                  .order("word_index #{order}")
      @pagy, @words = pagy(words, items: 500)
    end
  end

  def init_presenter
    @presenter = WordTextProofreadingsPresenter.new(self)
  end
end