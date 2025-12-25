class WordMistakesPresenter < ApplicationPresenter
  def mistake_color(frequency)
    @mistakes_colors_by_frequency ||= {}
    return @mistakes_colors_by_frequency[frequency] if @mistakes_colors_by_frequency[frequency]

    return 'inherit' if frequency.nil? || frequency <= 0

    freq = [frequency.to_f, 1.0].min.clamp(0.0, 1.0)

    yellow_r, yellow_g, yellow_b = 255, 200, 0
    orange_r, orange_g, orange_b = 255, 140, 0
    red_r, red_g, red_b = 255, 0, 0

    if freq <= 0.5
      t = freq * 2
      r = (yellow_r + (orange_r - yellow_r) * t).round
      g = (yellow_g + (orange_g - yellow_g) * t).round
      b = (yellow_b + (orange_b - yellow_b) * t).round
    else
      t = (freq - 0.5) * 2
      r = (orange_r + (red_r - orange_r) * t).round
      g = (orange_g + (red_g - orange_g) * t).round
      b = (orange_b + (red_b - orange_b) * t).round
    end

    @mistakes_colors_by_frequency[frequency] = "rgb(#{r}, #{g}, #{b})"
  end

  def mistake_glow_intensity(frequency)
    return 0 if frequency.nil? || frequency <= 0

    freq = [frequency.to_f, 1.0].min.clamp(0.0, 1.0)
    (freq * 20).round
  end

  def page_number
    (params[:page_number].presence || 1).to_i.abs
  end

  def page_data
    words = load_words
    {
      words: words,
      mistakes: load_mistakes(words)
    }
  end

  def line_mapping
    MushafLineAlignment
      .where(
        mushaf_id: 5,
        page_number: page_number)
      .index_by(&:line_number)
  end

  def mistake_context_words
    context_words = []

    current_position = word.position
    verse_words = Word.order(:position).where(verse_id: word.verse_id).index_by(&:position)

    (2.downto(1)).each do |offset|
      prev_position = current_position - offset
      if prev_position >= 1 && verse_words[prev_position]
        context_words << verse_words[prev_position]
      end
    end

    context_words << word

    (1..2).each do |offset|
      next_position = current_position + offset
      if verse_words[next_position]
        context_words << verse_words[next_position]
      end
    end

    context_mistakes = WordMistake
                         .where(word_id: context_words.map(&:id), char_start: nil, char_end: nil)
                         .group_by(&:word_id)

    {
      words: context_words,
      mistakes: context_mistakes
    }
  end

  def similar_words_data
    similar_words_query = Word.where(text_qpc_hafs: word.text_qpc_hafs)
                              .where.not(id: word.id)
                              .order('word_index ASC')

    page = [current_page, 1].max
    offset = (page - 1) * 100

    similar_words = similar_words_query.offset(offset).limit(per_page)
    similar_mistakes = WordMistake
                         .where(
                           word_id: similar_words.select(:id),
                           char_start: nil,
                           char_end: nil
                         )
                         .group_by(&:word_id)

    total_pages = (similar_words_query.count.to_f / 100).ceil

    {
      count: similar_words_query.count,
      pages: total_pages,
      words: similar_words,
      mistakes: similar_mistakes
    }
  end


  def word
    Word.find(params[:id])
  end

  def current_page
    params[:page]&.to_i || 1
  end

  def word_mistake
    WordMistake.find_by(word_id: word.id, char_start: nil, char_end: nil)
  end

  protected

  def load_words
    MushafWord
      .where(
        mushaf_id: 5,
        page_number: page_number
      )
      .order('position_in_page ASC')
  end

  def load_mistakes(words)
    WordMistake
      .where(word_id: words.select(:word_id))
      .group_by(&:word_id)
  end
end
