class Draft::Topic < ApplicationRecord
  include PaperTrailAttribution
  include DraftResourceStats

  FIELDS = %w[name arabic_name description].freeze

  belongs_to :topic, class_name: '::Topic'
  belongs_to :resource_content, optional: true
  belongs_to :user, optional: true

  # Fixes suggested by users that aren't approved yet
  scope :pending_contributions, -> { where.not(user_id: nil).where(imported: false) }

  before_save { self.text_matched = matches_current? }

  def changed_fields
    FIELDS.reject { |field| self["current_#{field}"].to_s.strip == self["draft_#{field}"].to_s.strip }
  end

  def matches_current?
    changed_fields.empty? && added_verse_ids.blank? && removed_verse_ids.blank?
  end

  def added_verses
    Verse.where(id: added_verse_ids).order(:verse_index)
  end

  def removed_verses
    Verse.where(id: removed_verse_ids).order(:verse_index)
  end

  def status
    if imported?
      'imported'
    elsif need_review?
      'needs review'
    else
      'approved'
    end
  end

  def import!
    changed_fields.each { |field| topic[field] = self["draft_#{field}"].to_s.strip.presence }

    attribute_versions_to(user) do
      ::Topic.transaction do
        topic.save(validate: false)

        added_verse_ids.each do |verse_id|
          ::VerseTopic.where(topic_id: topic.id, verse_id: verse_id).first_or_create!(
            ontology: topic.ontology,
            thematic: topic.thematic
          )
        end
        ::VerseTopic.where(topic_id: topic.id, verse_id: removed_verse_ids).destroy_all
      end
    end

    resource_content&.touch
    update_columns(imported: true)

    topic
  end
end
