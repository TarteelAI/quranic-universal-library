class ResourcesController < CommunityController
  include ActiveStorage::SetCurrent

  def index
    @resources = DownloadableResource
                   .published
                   .select('DISTINCT ON (resource_type) *, COUNT(*) OVER (PARTITION BY resource_type) AS total_resources')
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
    @resources = DownloadableResource.published.where(resource_type: params[:id])

    if @resources.empty?
      redirect_to resources_path, alert: 'Sorry, this resource does not exist.'
    end
  end
end