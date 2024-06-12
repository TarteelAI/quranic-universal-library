# frozen_string_literal: true

module Utils
  class TranslationAnalyzer < TextAnalyzer
    FOOT_NOTE_REG = %r{<sup foot_note="?\d+"?>\d+</sup>}

    def initialize(translation_id)
      super get_text(translation_id)
    end

    protected

    def get_text(id)
      translation = Translation.find(id).text
      translation.gsub(FOOT_NOTE_REG, '').gsub(/\W/, ' ')
    end
  end
end
