module Segments
  class Log < Base
    belongs_to :reciter, class_name: 'Segments::Reciter'
  end
end