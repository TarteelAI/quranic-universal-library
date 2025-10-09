class MorphologyPhrasesController < CommunityController
  before_action :find_resource
  before_action :authenticate_user!, only: %i[new edit create update destroy]
  before_action :authorize_access!, only: %i[new edit create update destroy]
  before_action :init_presenter
  def show
    if params[:proofread].present?
      @verse = Verse.find_by_id_or_key(params[:id])
    else
      @phrase = Morphology::Phrase.find(params[:id])

      if params[:result_type] == 'preview'
        return render 'preview', layout: false
      else
        @phrase_search = SimilarAyahPhraseSearch.new(@phrase.source_verse, [@phrase.word_position_from, @phrase.word_position_to], @phrase.id)

        @suggestions = @phrase_search.get_suggestions(
          @phrase.text_qpc_hafs,
          text_search: params[:use_text_search].to_i == 1 || params[:use_text_search].nil?,
          root: params[:use_root_search].to_i == 1,
          lemma: params[:use_root_search].to_i == 1,
          lcs: params[:use_lcs_search].to_i == 1
        )
      end
    end
  end

  def phrase_verses
    @phrase = Morphology::Phrase.find(params[:id])

    render layout: false if request.xhr?
  end

  def create
    builder = PhraseBuilderService.new(phrase_params)
    @phrase_verse = builder.run

    flash[:notice] = "Saved successfully"
  end

  def new
    if params[:add_ayah_key].present?
      render partial: 'morphology_phrases/add_ayah_suggestion'
    elsif params[:modal]
      render layout: false
    else
      ayah, range = nil

      if params[:ayah_key].present?
        ayah = Verse.find_by(verse_key: params[:ayah_key])
        range = [params[:word_from] || 1, params[:word_to] || ayah.words_count].map(&:to_i)
      end

      @phrase_search = SimilarAyahPhraseSearch.new(ayah, range)
      @phrase = @phrase_search.get_phrase(params[:text].presence)
      @existing_verses = @phrase.verses(eager_load: nil)

      @suggestions = @phrase_search.get_suggestions(
        params[:text].presence,
        text_search: params[:use_text_search].to_i == 1 || params[:use_text_search].nil?,
        root: params[:use_root_search].to_i == 1,
        lemma: params[:use_root_search].to_i == 1,
        lcs: params[:use_lcs_search].to_i == 1
      )
    end
  end

  def update
    @phrase_verse = Morphology::PhraseVerse.find(params[:id])

    if params.has_key?(:approved)
      flash[:notice] = "Phrase #{@phrase_verse.phrase_id} approved successfully"
      @phrase_verse.update(approved: true)
    else
      flash[:notice] = "Phrase #{@phrase_verse.phrase_id} disapproved successfully"
      @phrase_verse.update(approved: false)
    end
  end

  def index
    if params[:proofread].present?
      list = Verse

      if params[:filter_chapter].present?
        list = list.where(chapter_id: params[:filter_chapter])
      end

      if params[:verse_number].present?
        list = list.where(verse_number: params[:verse_number])
      end

      list = list.order("#{sort_key} #{sort_order}")

      @pagy, @verses = pagy(list)
    else
      load_phrases
    end
  end

  def destroy
    phrase = Morphology::Phrase.find(params[:phrase_id])
    @phrase_verse = phrase.phrase_verses.find_by(verse_id: params[:verse_id])

    if @phrase_verse
      @phrase_verse.update(review_status: 'remove', approved: false)
      flash[:notice] = 'This Ayah is unapproved for the phrase.'
    end
  end

  protected

  def sort_key
    sort_by = params[:sort_key].presence || 'source_verse_id'

    if params[:proofread].present?
      if ['id', 'verse_index'].include?(sort_by)
        sort_by
      else
        'verse_index'
      end
    else
      if ['id', 'occurrence', 'verses_count', 'words_count', 'approved', 'review_status'].include?(sort_by)
        sort_by
      else
        'source_verse_id'
      end
    end
  end

  def load_phrases
    list = Morphology::Phrase.includes(:source_verse)
    chapter = nil
    if params[:filter_chapter].present?
      # Can't use join here, phrases and verses are not in same table
      chapter = Chapter.find_by(id: params[:filter_chapter])
      list = list.where(source_verse_id: chapter.verses.pluck(:id)) if chapter
    end

    if params[:verse_number].present?
      verses = if chapter
                 chapter.verses
               else
                 Verse
               end
      verses = verses.where(verse_number: params[:verse_number])

      list = list.where(source_verse_id: verses.pluck(:id))
    end

    if params[:text].present?
      list = list.where("text_qpc_hafs like ?", "%#{params[:text].strip}%")
      list = list.or(list.where("text_qpc_hafs_simple like ?", "%#{params[:text].strip}%"))
    end

    list = list.order("#{sort_key} #{sort_order}")

    @pagy, @phrases = pagy(list)
  end

  def phrase_params
    params.require(:morphology_phrase).permit(
      :phrase_text,
      :verse_id,
      :source_ayah_key,
      :source_ayah_word_from,
      :source_ayah_word_to,
      :phrase_id,
      :selected_words,
      :excluded_words,
    )
  end

  def find_resource
    @resource ||= ResourceContent.where(sub_type: ResourceContent::SubType::Mutashabihat).first
  end

  def load_resource_access
    @access = can_manage?(find_resource)
  end

  def init_presenter
    @presenter = MorphologyPhrasesPresenter.new(self)
  end
end