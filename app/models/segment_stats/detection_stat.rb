class SegmentStats::DetectionStat < SegmentStats::Base
  self.table_name = 'detection_stats'
  belongs_to :reciter, class_name: 'SegmentStats::ReciterName', foreign_key: 'reciter_id', primary_key: 'id'
end