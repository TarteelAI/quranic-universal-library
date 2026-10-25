class WordConcordanceLabelsController < CommunityController
  before_action :normalize_page_param, only: %i[index]
  before_action :init_presenter
  before_action :authorize_access!, only: %i[update_segment update_word]
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
    load_word
  end

  def update_word
    return unless load_word

    if @word.save_edit(params.require(:corpus_word).permit(:case_reason, :description), current_user)
      redirect_to word_detail_word_concordance_label_path(@verse.id, word: @word.location), notice: 'Word saved.'
    else
      render :word_detail, status: :unprocessable_entity
    end
  end

  def segment_detail
    load_segment
  end

  def update_segment
    return unless load_segment

    if @segment.save_edit(segment_params, current_user)
      redirect_to segment_detail_word_concordance_label_path(@verse.id, word: @word.location, segment: @segment.position), notice: 'Segment saved.'
    else
      render :segment_detail, status: :unprocessable_entity
    end
  end

  def load_word
    @verse = Verse.find(params[:id])
    @word = @verse.morphology_words.includes(:word, :word_segments).find_by_location(params[:word])

    if @word.nil?
      redirect_to word_concordance_label_path(@verse.id), notice: "Can't find the word"
      return
    end

    @word
  end

  def load_segment
    @verse = Verse.find(params[:id])
    params[:word] ||= "#{@verse.verse_key}:1"

    @word = @verse.morphology_words.includes(:word, :word_segments).find_by_location(params[:word])

    if @word.nil?
      redirect_to word_concordance_label_path(@verse.id), notice: "Can't find the word"
      return
    end

    @segment = @word.word_segments[params[:segment].to_i - 1]

    if @segment.nil?
      redirect_to word_detail_word_concordance_label_path(@verse.id, word: @word.location), notice: "Can't find the segment"
      return
    end

    @segment
  end

  def segment_params
    params.require(:corpus_segment).permit(:part_of_speech, :verb_form, :root_id, :lemma_name, :case_reason,
                                           :grammar_term_desc_arabic, :grammar_term_desc_english,
                                           other_tags: [], features: Morphology::SegmentTags::FEATURES.keys + Morphology::SegmentTags::PGN.keys)
  end

  def load_resource_access
    @resource = ResourceContent.where(name: 'Corpus').first_or_create
    @access = can_manage?(@resource)
  end

  def init_presenter
    @presenter = WordConcordanceLabelsPresenter.new(self)
  end
end