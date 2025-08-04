module Segments
  class StateMachineLog < Base
    belongs_to :reciter, class_name: 'Segments::Reciter'
  end
end