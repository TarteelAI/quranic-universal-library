# == Schema Information
#
# Table name: related_topics
#
#  id               :integer          not null, primary key
#  topic_id         :integer
#  related_topic_id :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_related_topics_on_topic_id  (topic_id)
#

class RelatedTopic < QuranApiRecord
  belongs_to :topic, optional: true
  belongs_to :related_topic, class_name: 'Topic'
end
