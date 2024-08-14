class WbwTextsController < CommunityController
  before_action :load_resource
  before_action :authorize_access!, only: [:new, :create, :edit, :update]

  def index
    verses = Verse

    if params[:filter_juz].to_i > 0
      verses = verses.where(juz_number: params[:filter_juz].to_i)
    end

    if params[:filter_chapter].to_i > 0
      verses = verses.where(chapter_id: params[:filter_chapter].to_i)
    end

    if params[:filter_verse].to_i > 0
      verses = verses.where(verse_number: params[:filter_verse].to_i)
    end

    if params[:with_issues]
      pauses = WbwText.where(word_id: Word.where(char_type_id: 4).pluck(:id))
      words_with_issues = pauses.where("text_indopak != '' OR text_uthmani != '' OR text_imlaei != ''")

      verses = verses.where(id: words_with_issues.pluck(:verse_id).uniq)
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

  def edit
    @verse = Verse.find(params[:id])
    @wbw_texts = @verse.wbw_texts.order('word_id asc')
  end

  def create
    @verse = Verse.find(params[:verse_id])
    @verse.update(wbw_translations_params)

    redirect_to wbw_text_path(@verse)
  end

  protected

  def wbw_translations_params
    params.require(:verse).permit wbw_texts_attributes: [
      :word_id,
      :text_imlaei,
      :text_indopak,
      :text_uthmani,
      :text_qpc_hafs,
      :user_id,
      :id
    ]
  end

  def load_resource
    @resource ||= ResourceContent.find_by(id: 7)
  end

  def load_resource_access
    @access = can_manage?(@resource)
  end
end