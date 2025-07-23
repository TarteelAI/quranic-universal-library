class SegmentStats::FailureStat < SegmentStats::Base
  self.table_name = 'failures'
  belongs_to :reciter, class_name: 'SegmentStats::ReciterName', foreign_key: 'reciter_id', optional: true
end