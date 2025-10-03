# frozen_string_literal: true

class TopicSearch
  VERSE_KEY_PATTERN = /^\d+:\d+$/
  VALID_SORT_COLUMNS = %w[name parent ayahs_count].freeze
  VALID_SORT_DIRECTIONS = %w[asc desc].freeze

  attr_reader :query, :page, :per_page, :sort_by, :sort_direction

  def initialize(query: nil, page: 1, per_page: 100, sort_by: nil, sort_direction: 'asc')
    @query = query.to_s.strip
    @page = page.to_i
    @per_page = per_page
    @sort_by = VALID_SORT_COLUMNS.include?(sort_by.to_s) ? sort_by.to_s : 'name'
    @sort_direction = VALID_SORT_DIRECTIONS.include?(sort_direction.to_s) ? sort_direction.to_s : 'asc'
  end

  def results
    base_results = if query.blank?
      all_topics
    elsif verse_key_search?
      topics_by_verse
    else
      topics_by_text
    end

    apply_sorting(base_results)
  end

  def searched_verse
    @searched_verse ||= Verse.find_by(verse_key: query) if verse_key_search?
  end

  def verse_key_search?
    query.match?(VERSE_KEY_PATTERN)
  end

  private

  def all_topics
    Topic.includes(:verse_topics, :parent, :children)
  end

  def topics_by_verse
    verse = searched_verse
    return Topic.none unless verse

    topic_ids = verse.verse_topics.pluck(:topic_id)
    Topic.includes(:verse_topics, :parent, :children)
         .where(id: topic_ids)
  end

  def topics_by_text
    Topic.includes(:verse_topics, :parent, :children)
         .where(
           "LOWER(name) LIKE ? OR LOWER(arabic_name) LIKE ? OR LOWER(description) LIKE ?",
           "%#{query.downcase}%",
           "%#{query.downcase}%",
           "%#{query.downcase}%"
         )
  end

  def apply_sorting(scope)
    case sort_by
    when 'name'
      scope.order("LOWER(topics.name) #{sort_direction}")
    when 'parent'
      scope.joins("LEFT JOIN topics AS parent_topics ON topics.parent_id = parent_topics.id")
           .order("CASE WHEN parent_topics.name IS NULL THEN 1 ELSE 0 END, LOWER(parent_topics.name) #{sort_direction}")
    when 'ayahs_count'
      scope.select('topics.*, COUNT(verse_topics.id) as verse_count')
           .left_joins(:verse_topics)
           .group('topics.id')
           .order("COUNT(verse_topics.id) #{sort_direction}")
    else
      scope.order(:name)
    end
  end
end

