# frozen_string_literal: true

module Catalog
  # The search key of a text: the catalog search folds the query and the indexed text with it, so
  # they match whatever accents, harakat or letter variants either one is written with.
  #
  # Unicode compatibility decomposition splits accents, harakat, hamza and madda from their
  # letters (and opens ligatures and presentation forms); the combining marks are then dropped.
  # Tatweel is dropped, and the alef, ya and ta marbuta variants that do not decompose are folded.
  module TextKey
    TATWEEL = "ـ"
    # Alef wasla and the wavy-hamza alefs, alef maksura and Farsi ya, ta marbuta.
    VARIANTS = "ٱٲٳٵىیة"
    FOLDED = "ااااييه"

    module_function

    def call(text)
      text.to_s.unicode_normalize(:nfkd)
          .gsub(/\p{Mn}/, '')
          .delete(TATWEEL)
          .tr(VARIANTS, FOLDED)
          .downcase
          .gsub(/[^\p{L}\p{N}]+/, ' ')
          .strip
    end
  end
end
