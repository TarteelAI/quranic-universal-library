class WordConcordanceLabelsController < CommunityController
  before_action :init_presenter
  def index
    verses = Verse

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
    @verse = Verse.find(params[:id])
  end

  def word_detail
    @verse = Verse.find(params[:id])
    @word = @verse.morphology_words.includes(:word, :word_segments).find_by_location(params[:word])

    if @word.nil?
      redirect_to word_concordance_label_path(@verse.id), notice: "Can't find the word"
    end
  end

  def segment_detail
    @verse = Verse.find(params[:id])
    @word = @verse.morphology_words.includes(:word, :word_segments).find_by_location(params[:word])

    if @word.nil?
      redirect_to word_concordance_label_path(@verse.id), notice: "Can't find the word"
    end

    @segment = @word.word_segments[params[:segment].to_i - 1]

    if @segment.nil?
      redirect_to word_detail_word_concordance_label_path(@verse.id, word: @word.location), notice: "Can't find the segment"
    end
  end

  def update_segment

  end

  def load_resource_access
    @resource = ResourceContent.where(name: 'Corpus').first_or_create
    @access = can_manage?(@resource)
  end

  def init_presenter
    @presenter = WordConcordanceLabelsPresenter.new(self)
  end
end