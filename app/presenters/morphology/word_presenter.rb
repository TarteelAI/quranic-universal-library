module Morphology
  class WordPresenter < ApplicationPresenter
    attr_reader :locale, :location, :verse, :word, :morphology_word, :segments, :prev_word, :next_word

    def initialize(context)
      super(context)
      @locale = params[:locale].presence || 'ar'
      @location = normalize_location(params[:location])
      chapter_number, verse_number, word_position = parse_location(@location)

      @verse = Verse.find_by(chapter_id: chapter_number, verse_number: verse_number)
      @word = @verse&.words&.includes(:en_translation, :lemma, :root, :stem, :morphology_word)&.find_by(position: word_position)
      @prev_word = @word&.previous_word
      @next_word = @word&.next_word

      @morphology_word = @word&.morphology_word
      @segments = @morphology_word ? @morphology_word.word_segments.includes(:grammar_term, :grammar_concept, :grammar_role, :grammar_sub_role, :lemma, :root, :topic).to_a : []
    end

    def found?
      verse.present? && word.present?
    end

    def title
      return '' unless word
      "Grammar of #{word.position.ordinalize} word of ayah #{verse.verse_key}"
    end

    def word_location
      word&.location.to_s
    end

    def back_to_treebank_path
      return '' unless verse
      context.morphology_treebank_index_path(locale: locale, chapter_number: verse.chapter_id, verse_number: verse.verse_number, graph_number: 1)
    end

    def dependency_graph_path
      back_to_treebank_path
    end

    def ayah_key
      verse&.verse_key.to_s
    end

    def read_ayah_path
      return '' unless verse
      context.ayah_path(key: verse.verse_key)
    end

    def prev_word_path
      return nil unless prev_word
      context.morphology_word_path(locale: locale, location: prev_word.location)
    end

    def next_word_path
      return nil unless next_word
      context.morphology_word_path(locale: locale, location: next_word.location)
    end

    def topic_path(topic_id)
      return nil unless verse && topic_id.present?
      "/resources/ayah-topics/#{verse.id}?topic_id=#{topic_id}"
    end

    def topic_label(topic)
      return '' unless topic
      label = locale == 'ar' ? topic.arabic_name : topic.name
      label.presence || "Topic ##{topic.id}"
    end

    def meaning
      word&.en_translation&.text.presence || '-'
    end

    def transliteration
      word&.en_transliteration.presence || '-'
    end

    def description_html
      morphology_word&.description.to_s.presence || '-'
    end

    def corpus_image_url
      word&.corpus_image_url.to_s
    end

    def lemma_text
      word&.lemma&.text_madani.presence || '-'
    end

    def stem_text
      word&.stem&.text_madani.presence || '-'
    end

    def root_text
      word&.root&.value.presence || '-'
    end

    def lemma_modal_url
      return nil unless word&.lemma
      context.morphology_lemma_path(word.lemma.text_clean)
    end

    def stem_modal_url
      return nil unless word&.stem
      context.morphology_stem_path(word.stem.text_clean)
    end

    def root_modal_url
      return nil unless word&.root
      context.morphology_root_path(word.root.arabic_trilateral)
    end

    def case_text
      morphology_word&.case.presence || '-'
    end

    def case_reason_text
      morphology_word&.case_reason.presence || '-'
    end

    def pos_styles
      {
        "N" => "tw-border-sky-200 tw-bg-sky-50 tw-text-sky-900",
        "PN" => "tw-border-blue-200 tw-bg-blue-50 tw-text-blue-900",
        "V" => "tw-border-emerald-200 tw-bg-emerald-50 tw-text-emerald-900",
        "P" => "tw-border-amber-200 tw-bg-amber-50 tw-text-amber-900",
        "CONJ" => "tw-border-indigo-200 tw-bg-indigo-50 tw-text-indigo-900",
        "PRON" => "tw-border-teal-200 tw-bg-teal-50 tw-text-teal-900",
        "DET" => "tw-border-gray-200 tw-bg-gray-50 tw-text-gray-900"
      }
    end

    def pos_text_styles
      {
        "N" => "sky",
        "PN" => "blue",
        "V" => "seagreen",
        "P" => "rust",
        "CONJ" => "navy",
        "PRON" => "sky-dark",
        "DET" => "gray",
        "ADJ" => "purple",
        "REL" => "gold",
        "DEM" => "brown",
        "NEG" => "red"
      }
    end

    def pos_text_class(pos_key)
      key = pos_key.to_s.upcase
      pos_text_styles[key] || "metal"
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


