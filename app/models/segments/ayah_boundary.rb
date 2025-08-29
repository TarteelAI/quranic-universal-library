module Segments
  class AyahBoundary < Base
    belongs_to :reciter, class_name: 'Segments::Reciter', optional: true
    belongs_to :verse
  end
end