class MorphologyPhrasesController < CommunityController
  before_action :normalize_page_param, only: %i[index]
  before_action :find_resource
  before_action :authenticate_user!, only: %i[new edit create update destroy review_ayah merge]
  before_action :authorize_access!, only: %i[new edit create update destroy review_ayah merge]
  before_action :init_presenter
  def show
    if params[:proofread].present?
      if @presenter.verse.blank?
        redirect_to morphology_phrases_path(proofread: true), alert: 'Sorry ayah not found.'
      end
    elsif params[:result_type] == 'preview'
      @phrase = @presenter.phrase
      render 'preview', layout: false
    elsif @presenter.review.blank?
      redirect_to morphology_phrases_path, alert: "Phrase #{params[:id]} has no source ayah to build from."
    end
  end

  # Auto-detected shared phrases for an ayah, loaded into the ayah page
  def detect
    return head(:not_found) if @presenter.verse.blank?

    render layout: false
  end

  # Ayahs of a phrase, loaded when its ayah count is expanded on the ayah page
  def ayahs
    render layout: false
  end

  # Approve, disapprove or remove one ayah row of a phrase
  def review_ayah
    @phrase_verse = @presenter.phrase.phrase_verses.find(params[:phrase_verse_id])

    case params[:status]
    when 'approve'
      @phrase_verse.update(approved: true, review_status: 'new')
    when 'disapprove'
      @phrase_verse.update(approved: false, review_status: 'new')
    when 'remove'
      @phrase_verse.update(approved: false, review_status: 'remove')
    else
      return head(:bad_request)
    end

    @presenter.phrase.update_verses_stats
    flash.now[:notice] = "#{@phrase_verse.verse.verse_key} #{params[:status] == 'remove' ? 'removed from' : "#{params[:status]}d for"} phrase #{@phrase_verse.phrase_id}"
  end

  # Merge duplicate phrases into the one to keep, then delete the duplicates
  def merge
    keep = Morphology::Phrase.find(params[:keep_id])
    duplicates = Morphology::Phrase.where(id: Array(params[:phrase_ids])).where.not(id: keep.id).to_a
    merge = Mutashabihat::PhraseMerge.new(keep, duplicates).run

    redirect_back fallback_location: morphology_phrase_path(keep.id),
                  notice: "Merged #{duplicates.map { |p| "##{p.id}" }.to_sentence} into ##{keep.id}: #{helpers.pluralize(merge.moved, 'ayah')} moved, #{merge.combined} already there."
  end

  def phrase_verses
    @phrase = Morphology::Phrase.find(params[:id])

    render layout: false if request.xhr?
  end

  def create
    builder = PhraseBuilderService.new(phrase_params)
    @verse = Verse.find(phrase_params[:verse_id])

    if builder.selected_ranges.blank?
      flash.now[:alert] = 'Select at least one word range before saving.'
      return render turbo_stream: turbo_stream.replace('flash-messages', partial: 'shared/flash_notices')
    end

    @phrase_verses = builder.run
    @phrase = builder.phrase

    flash.now[:notice] = "Saved #{@verse.verse_key} with #{helpers.pluralize(@phrase_verses.size, 'range')}"
  end

  def new
    if params[:add_ayah_key].present?
      render partial: 'morphology_phrases/add_ayah_suggestion', formats: :turbo_stream
    elsif params[:modal]
      render layout: false
    elsif (params[:ayah_key].present? || params[:text].present?) && @presenter.review.blank?
      flash.now[:alert] = 'Could not find that ayah or phrase in the Quran.'
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
      list = @presenter.proofread_verses

      if MorphologyPhrasesPresenter::STATS_SORT_KEYS.include?(params[:sort_key])
        # Phrase stats aren't columns, so sort ids in memory
        ids = @presenter.sorted_verse_ids(list, params[:sort_key], sort_order)
        @pagy, page_ids = pagy_array(ids)
        @verses = Verse.where(id: page_ids).sort_by { |v| page_ids.index(v.id) }
      else
        @pagy, @verses = pagy(list.order("#{sort_key} #{sort_order}"))
      end
    else
      load_phrases
    end
  end

  def destroy
    phrase = Morphology::Phrase.find(params[:phrase_id])
    @verse = Verse.find(params[:verse_id])
    phrase_verses = phrase.phrase_verses.where(verse_id: @verse.id)

    if phrase_verses.exists?
      phrase_verses.update_all(review_status: 'remove', approved: false)
      phrase.update_verses_stats
      flash.now[:notice] = "#{@verse.verse_key} removed from this phrase."
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

    case params[:filter_source]
    when 'imported'
      list = list.where(source: Morphology::Phrase::SOURCE_IMPORTED)
    when 'pending_ayahs'
      # Ayahs nobody has checked and not approved yet, e.g. the ones an
      # import added to saved phrases
      list = list.where(id: Morphology::PhraseVerse.where(review_status: nil, approved: false).select(:phrase_id))
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
      :ranges,
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