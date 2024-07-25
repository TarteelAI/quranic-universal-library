class ResourcesController < CommunityController
  include ActiveStorage::SetCurrent

  def index
    @resources = DownloadableResource
      .published
      .select('DISTINCT ON (resource_type) *, COUNT(*) OVER (PARTITION BY resource_type) AS total_resources')
  end

  def show
    @resources = DownloadableResource.published.where(resource_type: params[:id])
  end
end