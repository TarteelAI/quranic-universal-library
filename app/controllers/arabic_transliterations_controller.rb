class ArabicTransliterationsController < CommunityController
  before_action :authenticate_user!, only: [:new, :create]
  before_action :authorize_access!, only: [:new, :create]
  before_action :init_presenter
  def show
    @verse = Verse.includes(words: :arabic_transliteration).find(params[:id])

    saved_page = @verse.arabic_transliterations.detect(&:page_number)
    @predicted_page = saved_page&.page_number || (@verse.page_number * 1.6666).to_i
  end

  def render_surah
    @chapter = Chapter.find(params[:surah_number])

    verses = @chapter
      .verses
      .eager_load(words: :arabic_transliteration)
      .order("verse_index asc, words.position asc")

    respond_to do |format|
      html = render_to_string({
          template: "arabic_transliterations/export",
          layout: 'pdf',
          formats: [:html],
          locals: {
            verses: verses,
            chapter: @chapter
          }
        }
      )

      #format.pdf {
      #   pdf = Grover.new(html).to_pdf
      #  send_data pdf, filename: "#{@chapter.id}.pdf", type: "application/pdf", disposition: 'inline'
      #}

      format.html{ render html: html }
    end
  end

  def new
    @verse = Verse.includes(:chapter).find(params[:ayah])

    indopak = @verse.text_indopak.strip.split(/\s+/)
    pause_mark_count = 0
    @arabic_transliterations = []

    saved_page = @verse.arabic_transliterations.detect(&:page_number)
    @predicted_page = saved_page&.page_number || (@verse.page_number * 1.6666).to_i

    @verse.words.order('position asc').each_with_index do |word, i|
      next if word.char_type_name == 'end'
      transliteration = @verse.arabic_transliterations.find_or_initialize_by(word_id: word.id)

      if word.char_type_name == 'word'
        transliteration.indopak_text ||= indopak[i - pause_mark_count]
      else
        pause_mark_count += 1
      end

      transliteration.page_number ||= @predicted_page

      @arabic_transliterations << transliteration
    end
  end

  def index
    verses = case params[:filter_progress]
             when 'completed'
               Verse.verse_with_full_arabic_transliterations
             when 'missing'
               Verse.verses_with_no_arabic_translitration
             when 'all'
               Verse.verse_with_words_and_arabic_transliterations
             else
               Verse.verses_with_missing_arabic_translitration
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

  def create
    verse = Verse.find(params[:verse_id])
    verse.attributes = arabic_transliterations_params
    verse.save validate: false
    redirect_to arabic_transliteration_path(verse), notice: "Saved successfully"
  end

  protected

  def arabic_transliterations_params
    params.require(:verse).permit arabic_transliterations_attributes: [
        :id,
        :indopak_text,
        :ur_translation,
        :text,
        :word_id,
        :page_number,
        :position_x,
        :position_y,
        :zoom,
        :continuous
    ]
  end

  def load_resource_access
    @resource = ResourceContent.transliteration.one_word.for_language('ar').first
    @access = can_manage?(@resource)
  end

  def init_presenter
    @presenter = ArabicTransliterationsPresenter.new(self)
  end
end
