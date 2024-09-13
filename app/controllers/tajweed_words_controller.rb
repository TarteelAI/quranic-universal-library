class TajweedWordsController < CommunityController
  before_action :find_resource
  before_action :authenticate_user!, only: %i[update]
  before_action :authorize_access!, only: %i[update]

  def show
    @word = Word.find_by(location: params[:id])
    @tajweed_word = TajweedWord.where(word_id: @word.id).first
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

  def rule_doc

  end

  def update
    @word = Word.find_by(location: params[:id])
    @tajweed_word = TajweedWord.where(word_id: @word.id).first
    p = rule_params
    @letter = @tajweed_word.update_letter_rule(p[:letter_index], p[:rule])
  end

  protected

  def rule_params
    params.require(:tajweed_word).permit(:letter_index, :rule)
  end

  def load_resource_access
    @access = can_manage?(find_resource)
  end

  def find_resource
    @resource ||= ResourceContent.find(1140)
  end
end