module Utils
  class TextAnalyzer
    METHODS = [
      'get_nouns',
      'get_proper_nouns',
      'get_past_tense_verbs',
      'get_adjectives',
      'get_noun_phrases',
      'get_max_noun_phrases',
      # Returns all types of conjunctions and does not discriminate between the various kinds.
      # E.g. coordinating, subordinating, correlative...
      'get_conjunctions',
      'get_question_parts', # also called get_interrogatives.
      'get_adverbs',
      'get_verbs'
    ].freeze
    attr_reader :text, :tagger, :tagged

    def initialize(text)
      @text = text
      @tagger = EngTagger.new(stem: true)
      @tagged = tagger.add_tags(text)
    end

    METHODS.each do |method_name|
      define_method method_name do
        tagger.send(method_name, tagged)
      end
    end

    def get_words
      tagger.get_words(text)
    end
  end
end