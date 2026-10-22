class PhraseBuilderService
  attr_reader :phrase

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
    save_phrase_verses
  end

  # Word ranges picked for the ayah, sorted, with overlapping ranges merged.
  # e.g. "[[5,8],[1,3],[3,4]]" => [[1, 4], [5, 8]]
  def selected_ranges
    @selected_ranges ||= begin
      ranges = parse_ranges

      ranges.sort.each_with_object([]) do |(from, to), merged|
        if merged.any? && from <= merged.last[1]
          merged.last[1] = [merged.last[1], to].max
        else
          merged << [from, to]
        end
      end
    end
  end

  protected

  # Each range is stored as its own phrase verse row, so a phrase can be
  # matched more than once in the same ayah. Rows for ranges that are no
  # longer selected are marked as removed, not deleted.
  def save_phrase_verses
    return [] if @params[:verse_id].blank?

    excluded_words = @params[:excluded_words].to_s.split(',').map(&:to_i)
    existing = @phrase.phrase_verses.where(verse_id: @params[:verse_id]).order(:id).to_a

    # Keep rows whose range didn't change, reuse the rest for the new ranges.
    unchanged = selected_ranges.map do |from, to|
      existing.detect { |row| row.word_position_from == from && row.word_position_to == to }
    end
    reusable = existing - unchanged.compact

    saved = selected_ranges.each_with_index.map do |(from, to), index|
      phrase_verse = unchanged[index] || reusable.shift || @phrase.phrase_verses.new(verse_id: @params[:verse_id])
      missing_words = excluded_words.select { |position| position.between?(from, to) }

      phrase_verse.word_position_from = from
      phrase_verse.word_position_to = to
      phrase_verse.matched_words_count = (to - from + 1) - missing_words.size
      phrase_verse.missing_word_positions = missing_words
      phrase_verse.review_status = 'new'
      # Saving from the builder is the reviewer approving this ayah
      phrase_verse.approved = true
      phrase_verse.save(validate: false)

      phrase_verse
    end

    reusable.each do |phrase_verse|
      phrase_verse.update_columns(review_status: 'remove', approved: false)
    end

    @phrase.update_verses_stats
    saved
  end

  def parse_ranges
    if @params[:ranges].present?
      ranges = JSON.parse(@params[:ranges].to_s) rescue []

      Array(ranges).filter_map do |range|
        from, to = Array(range).first(2).map(&:to_i)
        [from, to].minmax if from.positive? && to.positive?
      end
    else
      # Older clients send a flat list of selected word positions
      selected_words = @params[:selected_words].to_s.split(',').map(&:to_i).select(&:positive?)
      selected_words.any? ? [selected_words.minmax] : []
    end
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
    @phrase.approved = true
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