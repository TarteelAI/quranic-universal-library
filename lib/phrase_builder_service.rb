class PhraseBuilderService
  def initialize(params)
    @params = params
  end

  #TODO: move this to a new service
  def update_phrase_verses
    Morphology::PhraseVerse.where(matched_words_count: [0, nil]).find_each do |v|
      if v.word_position_to && v.word_position_from
        v.update matched_words_count: (v.word_position_to - v.word_position_from) + 1
      end
    end
  end

  def run
    find_or_create_phrase
    create_phrase_verse
  end

  protected

  def create_phrase_verse
    return if @params[:verse_id].blank?

    phrase_verse = @phrase.phrase_verses.where(verse_id: @params[:verse_id]).first_or_initialize
    selected_words = @params[:selected_words].to_s.split(',').map(&:to_i)
    missing_words = @params[:excluded_words].to_s.split(',').map(&:to_i)

    phrase_verse.word_position_from = selected_words.min
    phrase_verse.word_position_to = selected_words.max
    phrase_verse.matched_words_count = selected_words.size
    phrase_verse.missing_word_positions = missing_words
    phrase_verse.review_status = 'new'
    phrase_verse.save(validate: false)

    phrase_verse
  end

  def find_or_create_phrase
    if @params[:phrase_id].present?
      @phrase = Morphology::Phrase.find(@params[:phrase_id])
    else
      text = @params[:phrase_text].to_s.strip
      @phrase = Morphology::Phrase.where("text_qpc_hafs_simple = :simple OR text_qpc_hafs = :text", simple: text.remove_diacritics, text: text).first
      @phrase ||= Morphology::Phrase.new(
        text_qpc_hafs_simple: text.remove_diacritics,
        text_qpc_hafs: text
      )
    end

    @phrase.review_status = 'new'
    @phrase.word_position_from = @params[:source_ayah_word_from] || @phrase.word_position_from
    @phrase.word_position_to = @params[:source_ayah_word_to] || @phrase.word_position_to

    if @phrase.source_verse.blank?
      @phrase.source_verse = Verse.find_by_verse_key(@params[:source_ayah_key])
    end

    words = @phrase.source_verse
                   .words
                   .where(position: @phrase.word_position_from..@phrase.word_position_to)
                   .order('position ASC')

    @phrase.text_qpc_hafs_simple = words.map(&:text_qpc_hafs).join(' ').remove_diacritics
    @phrase.text_qpc_hafs = words.map(&:text_qpc_hafs).join(' ')
    @phrase.save(validate: false)

    @phrase
  end
end