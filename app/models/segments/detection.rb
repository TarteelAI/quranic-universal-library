class Segments::DetectionStat < Base
  self.table_name = 'detection_stats'
  belongs_to :reciter, class_name: 'Segments::Reciter', foreign_key: 'reciter_id', primary_key: 'id'
end