module Morphology
  class WordsController < ApplicationController
    def show
      @locale = params[:locale].presence || 'ar'
      @location = normalize_location(params[:location])
      chapter_number, verse_number, word_position = parse_location(@location)

      @verse = Verse.find_by(chapter_id: chapter_number, verse_number: verse_number)
      return head :not_found unless @verse

      @word = @verse.words.includes(:en_translation, :lemma, :root, :stem, :morphology_word).find_by(position: word_position)
      return head :not_found unless @word

      @prev_word = @word.previous_word
      @next_word = @word.next_word

      @morphology_word = @word.morphology_word
      @segments = @morphology_word&.word_segments&.includes(:grammar_term, :grammar_concept, :grammar_role, :grammar_sub_role, :lemma, :root, :topic)&.to_a || []
      @verb_forms = @morphology_word ? @morphology_word.verb_forms.order(:name).to_a : []
      @derived_words = @morphology_word ? @morphology_word.derived_words.includes(:verse, :word, :word_verb_from).to_a : []
    end

    private

    def normalize_location(location)
      location.to_s.strip.delete_prefix('(').delete_suffix(')')
    end

    def parse_location(location)
      parts = location.split(':').map(&:to_i)
      return [0, 0, 0] unless parts.length >= 3
      parts.first(3)
    end
  end
end


