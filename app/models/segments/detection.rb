module Segments
  class Detection < Base
    belongs_to :reciter, class_name: 'Segments::Reciter'
  end
end