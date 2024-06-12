# == Schema Information
#
# Table name: verse_topics
#
#  id          :bigint           not null, primary key
#  ontology    :boolean          default(FALSE)
#  thematic    :boolean          default(FALSE)
#  topic_words :jsonb
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  topic_id    :integer
#  verse_id    :integer
#
# Indexes
#
#  index_verse_topics_on_topic_id  (topic_id)
#  index_verse_topics_on_verse_id  (verse_id)
#
class VerseTopic < QuranApiRecord
  belongs_to :verse
  belongs_to :topic
end
