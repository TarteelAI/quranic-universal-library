module Segments
  class Failure < Base
    belongs_to :reciter, class_name: 'Segments::Reciter'
  end
end