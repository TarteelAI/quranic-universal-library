class TajweedWordsController < CommunityController
  before_action :find_resource
  before_action :authenticate_user!, only: %i[edit update]
  before_action :authorize_access!, only: %i[edit update]

  def show
    @word = Word.find_by(location: params[:id])
  end

  def index
    words = Word.unscoped

    if params[:filter_juz].to_i > 0
      words = words.where(juz_number: params[:filter_juz].to_i)
    end

    if params[:filter_chapter].to_i > 0
      words = words.where(chapter_id: params[:filter_chapter].to_i)
    end

    if params[:filter_verse].to_i > 0
      words = words.where(verse_number: params[:filter_verse].to_i)
    end

    params[:sort_key] ||= 'word_index'
    @pagy, @words = pagy(words.order("#{params[:sort_key]} #{sort_order}"))
  end

  def edit
  end

  def update
  end

  protected

  def load_resource_access
    @access = can_manage?(find_resource)
  end

  def find_resource
    @resource ||= ResourceContent.find(1140)
  end
end