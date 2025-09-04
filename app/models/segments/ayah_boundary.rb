module Segments
  class AyahBoundary < Base
    attr_accessor :words_data
    belongs_to :reciter, class_name: 'Segments::Reciter', optional: true
    belongs_to :verse

    def set_words_data(data)
      @words_data = data
    end
  end
end