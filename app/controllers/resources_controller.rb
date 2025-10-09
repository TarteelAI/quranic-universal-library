class ResourcesController < CommunityController
  include ActiveStorage::SetCurrent
  before_action :authenticate_user!, only: [:download]
  before_action :init_presenter

  def index
    @resources = view_context.downloadable_resource_cards.values

    sort_by = params[:sort_key]
    sort_order = params[:sort_order]

    if sort_by.present? && ['name', 'count'].include?(sort_by)
      @resources = @resources.sort_by { |resource| resource[sort_by.to_sym] }
      @resources.reverse! if sort_order == 'desc'
    end
  end

  def detail
    @resource = DownloadableResource
                  .published
                  .includes(:downloadable_resource_tags, :related_resources)
                  .find(params[:id])

    @presenter.set_resource(@resource)

    if params[:type] == 'ayah-topics'
      handle_ayah_topics
    end
  end

  def related_resources
    @resource = DownloadableResource
                  .published
                  .includes(:downloadable_resource_tags, :related_resources)
                  .find(params[:id])
    @presenter.set_resource(@resource)
  end

  def copyright
    @resource = DownloadableResource
                  .published
                  .find(params[:id])

    if request.xhr?
      render layout: false
    end
  end

  def download
    if file = DownloadableFile.find_by(token: params[:token])
      file.track_download(current_user)
      redirect_to file.file.url
    else
      redirect_to resource_path(params[:resource_id]), alert: 'Sorry, this resource does not exist.'
    end
  end

  def show
    @resources = DownloadableResource
                   .published
                   .includes(:downloadable_resource_tags, :related_resources)
                   .where(resource_type: params[:id])

    sort_by = params[:sort_key]
    sort_order = params[:sort_order].to_s == 'desc' ? 'desc' : 'asc'

    if sort_by.present? && ['name'].include?(sort_by)
      @resources = @resources.order("name #{sort_order}")
    end
    @presenter.set_resource(@resources.first)

    if @resources.empty?
      redirect_to resources_path, alert: 'Sorry, this resource does not exist.'
    end
  end

  protected

  def set_resource
    @resource = DownloadableResource.published.find(params[:id])
  end

  def sort_with_zero_last(collection, attribute, direction)
    # Split attribute path for nested attributes (e.g., 'verse.verse_number')
    attrs = attribute.split('.')
    
    sorted = collection.sort_by do |item|
      value = attrs.reduce(item) { |obj, attr| obj.send(attr) }
      # For ascending sort, put 0 at the end by treating it as infinity
      if direction == 'asc'
        value == 0 ? Float::INFINITY : value
      else
        value
      end
    end
    
    direction == 'desc' ? sorted.reverse : sorted
  end

  def init_presenter
    presenter_mapper = {
      mushaf_layout: MushafLayoutResourcesPresenter,
      translation: TranslationResourcePresenter,
      transliteration: TranslationResourcePresenter,
      tafsir: TafsirResourcePresenter
    }

    if action_name == 'show'
      resource_key = params[:id]
    elsif action_name == 'detail'
      resource_key = params[:type]
    end
    resource_key =resource_key.to_s.tr('-', '_').to_sym
    presenter_class = presenter_mapper[resource_key] || ResourcePresenter

    @presenter = presenter_class.new(self)
  end

  def handle_ayah_topics
    #TODO: Move logic to presenter
    if params[:topic_id].present?
      @topic = Topic.find_by(id: params[:topic_id])
      @verse_topics = @topic&.verse_topics&.includes(
        verse: [
          :chapter, 
          :words, 
          { translations: :language }
        ]
      ) || []
      
      @ayahs_sort = params[:ayahs_sort] || 'asc'
      
      if @verse_topics.any?
        @sorted_verse_topics = sort_with_zero_last(@verse_topics.to_a, 'verse.verse_number', @ayahs_sort)
      end
    else
      search = TopicSearch.new(
        query: params[:search],
        page: params[:page],
        per_page: 100,
        sort_by: params[:sort_by],
        sort_direction: params[:sort_direction]
      )

      @pagy, @topics = pagy(search.results, items: 100, page: params[:page] || 1)
      
      @search_query = search.query
      @sort_by = search.sort_by
      @sort_direction = search.sort_direction
      @searched_verse = search.searched_verse if search.verse_key_search?
      @is_verse_search = search.verse_key_search?
    end
  end
end