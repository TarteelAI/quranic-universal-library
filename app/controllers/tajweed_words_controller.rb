require "unicode/name"

class TajweedWordsController < CommunityController
  before_action :find_resource
  before_action :authenticate_user!, only: %i[update]
  before_action :authorize_access!, only: %i[update]
  before_action :init_presenter
  def show
    @word = Word.find_by(location: params[:id])
    @tajweed_word = TajweedWord.where(word_id: @word.id).first
  end

  def index
    words = Word.unscoped
    words = apply_surah_or_ayah_filter(words)
    words = apply_text_search_filter(words)
    words = apply_text_tajweed_rule_filter(words)

    params[:sort_key] ||= 'word_index'
    @pagy, @words = pagy(words.includes(:tajweed_word).order("#{sort_key} #{sort_order}"))
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

  def apply_surah_or_ayah_filter(words)
    if params[:filter_page].to_i > 0
      words = words.where(page_number: params[:filter_page].to_i)
    end

    if params[:filter_chapter].to_i > 0
      words = words.where(chapter_id: params[:filter_chapter].to_i)
    end

    if params[:verse_number].to_i > 0
      words = words.where(verse_id: Verse.where(verse_number: params[:verse_number].to_i))
    end

    words
  end

  def apply_text_search_filter(words)
    if params[:filter_text].present?
      words = QuranWordFinder.new(words).find_by_letters(params[:filter_text].strip)
    end

    if params[:filter_regexp_start].present? || params[:filter_regexp_end].present?
      finder = QuranWordFinder.new(words)

      if params[:filter_regexp_start].present? && params[:filter_regexp_end].present?
        if params[:filter_word_boundary] == '1'
          words = finder.find_by_start_and_end(params[:filter_regexp_start].strip, params[:filter_regexp_end].strip)
        else
          words = finder.find_by_letter_range(params[:filter_regexp_start].strip, params[:filter_regexp_end].strip)
        end
      elsif params[:filter_regexp_start].present?
        words = finder.find_by_starting_letter(params[:filter_regexp_start].strip)
      else
        words = finder.find_by_ending_letter(params[:filter_regexp_end].strip)
      end
    end

    words
  end

  def apply_text_tajweed_rule_filter(words)
    #if params[:filter_tajweed_rule_old].present?
    #  rule = params[:filter_tajweed_rule_old].downcase.strip
    #  words = words.where("text_uthmani_tajweed LIKE ?", "%#{rule}%")
    #end

    if params[:filter_tajweed_rule_new].present?
      rule = params[:filter_tajweed_rule_new].downcase.strip
      words = words.where("text_qpc_hafs_tajweed LIKE ?", "%#{rule}%")
    end

    words
  end

  def sort_key
    sort_by = params[:sort_key].presence || 'word_index'

    if ['word_index', 'location'].include?(sort_by)
      sort_by
    else
      "word_index"
    end
  end

  def init_presenter
    @presenter = TajweedWordsPresenter.new(self)
  end
end