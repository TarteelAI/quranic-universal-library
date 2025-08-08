module Segments
  class Position < Base
    belongs_to :reciter, class_name: 'Segments::Reciter'
  end
end