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
end