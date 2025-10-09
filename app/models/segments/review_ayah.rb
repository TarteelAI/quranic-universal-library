module Segments
  class ReviewAyah < Base
    belongs_to :reciter, class_name: 'Segments::Reciter'
    belongs_to :verse
  end
end