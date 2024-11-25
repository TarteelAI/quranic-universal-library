class ResourcesController < CommunityController
  include ActiveStorage::SetCurrent
  before_action :authenticate_user!, only: [:download]

  def index
    #@resources = DownloadableResource
    #                 .published
    #                 .select('DISTINCT ON (resource_type) *, COUNT(*) OVER (PARTITION BY resource_type) AS total_resources')

    @resources = view_context.downloadable_resource_cards.values

    sort_by = params[:sort_key]
    sort_order = params[:sort_order]

    if sort_by.present? && ['name', 'count'].include?(sort_by)
      @resources = @resources.sort_by { |resource| resource[sort_by.to_sym] }
      @resources.reverse! if sort_order == 'desc'
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
                   .includes(:downloadable_resource_tags)
                   .where(resource_type: params[:id])

    sort_by = params[:sort_key]
    sort_order = params[:sort_order].to_s == 'desc' ? 'desc' : 'asc'

    if sort_by.present? && ['name'].include?(sort_by)
      @resources = @resources.order("name #{sort_order}")
    end

    if @resources.empty?
      redirect_to resources_path, alert: 'Sorry, this resource does not exist.'
    end
  end
end