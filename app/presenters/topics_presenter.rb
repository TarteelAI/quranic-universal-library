class TopicsPresenter < ApplicationPresenter
  def resources
    ResourceContent.where(id: Topic.where.not(resource_content_id: nil).distinct.select(:resource_content_id)).order(:name)
  end

  # nil lists topics of every resource
  def resource
    return @resource if defined?(@resource)

    @resource = ResourceContent.find_by(id: params[:resource_id]) if params[:resource_id].present?
  end

  def topics
    list = Topic.all
    list = list.where(resource_content_id: resource.id) if resource
    list = list.verse_id_eq(filtered_verse.id) if filtered_verse

    if params[:query].present?
      query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:query].strip)}%"
      list = list.where('topics.name ILIKE :query OR topics.arabic_name ILIKE :query', query: query)
    end

    paginate(list.order('topics.name'))
  end

  def filtered_verse
    return @filtered_verse if defined?(@filtered_verse)

    @filtered_verse = Verse.find_by(verse_key: params[:verse_key].strip) if params[:verse_key].present?
  end

  # { topic_id => number of ayahs }
  def ayah_counts(topics)
    VerseTopic.where(topic_id: topics.map(&:id)).group(:topic_id).count
  end

  def topic
    @topic ||= Topic.find(params[:id])
  end

  def ayahs
    @ayahs ||= paginate(topic.verses.includes(:chapter).order(:verse_index))
  end

  def all_ayahs
    @all_ayahs ||= topic.verses.order(:verse_index).select(:id, :verse_key).to_a
  end

  def pending_suggestions
    Draft::Topic.pending_contributions.where(topic_id: topic.id).includes(:user).order(:created_at)
  end

  def page_title
    case action_name
    when 'show'
      topic.name
    when 'edit', 'update'
      "Suggest a fix: #{topic.name}"
    else
      'Ayah topics'
    end
  end

  def meta_title
    page_title
  end

  def meta_description
    'Proofread and suggest fixes for topics and the ayahs linked to each topic.'
  end
end
