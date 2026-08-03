class ProfilePresenter < ApplicationPresenter
  CONTRIBUTIONS_PER_PAGE = 25

  CONTRIBUTION_ICONS = {
    "Translation" => "TR",
    "Tafsir" => "TF",
    "Word" => "WD",
    "Verse" => "VS",
    "FootNote" => "FN",
    "Transliteration" => "TL",
    "ArabicTransliteration" => "AT"
  }.freeze

  def meta_title
    'Your Profile — Quranic Universal Library'
  end

  def user
    context.current_user
  end

  TABS = %w[downloads contributions resources].freeze

  def tab
    @tab ||= TABS.include?(params[:tab]) ? params[:tab] : "downloads"
  end

  def downloads?
    tab == "downloads"
  end

  def contributions?
    tab == "contributions"
  end

  def resources?
    tab == "resources"
  end

  def editable_resources
    @editable_resources ||= begin
      scope = user.user_projects
                  .includes(:resource_content)
                  .order(approved: :desc, updated_at: :desc)
      scope = scope.where(resource_content_id: filtered_resource_content_ids) if resource_type_filter
      scope
    end
  end

  def editable_resources_count
    @editable_resources_count ||= user.user_projects.count
  end

  def resource_types
    @resource_types ||= project_resource_contents.map(&:sub_type).compact.uniq.sort
  end

  def resource_type_filter
    @resource_type_filter ||= params[:resource_type].presence
  end

  def downloads
    @downloads ||= begin
      scope = user.user_downloads
                  .includes(:downloadable_resource)
                  .order(Arel.sql("last_download_at DESC NULLS LAST"))
      scope = scope.joins(:downloadable_resource).where(downloadable_resources: { resource_type: download_type }) if download_type
      scope
    end
  end

  def downloads_count
    @downloads_count ||= user.user_downloads.count
  end

  def download_types
    @download_types ||= user.user_downloads
                            .joins(:downloadable_resource)
                            .distinct
                            .pluck("downloadable_resources.resource_type")
                            .compact.sort
  end

  def download_type
    @download_type ||= params[:download_type].presence
  end

  def download_updated_since?(user_download)
    resource = user_download.downloadable_resource
    return false unless resource && user_download.last_download_at

    resource.updated_at > user_download.last_download_at
  end

  def download_resource_type_label(resource)
    return if resource.nil?

    resource.resource_type.to_s.tr("-", " ").humanize
  end

  def contributions_scope
    @contributions_scope ||= PaperTrail::Version.where(user_id: user.id)
  end

  def contributions_count
    @contributions_count ||= contributions_scope.count
  end

  def contribution_types
    @contribution_types ||= contributions_scope.distinct.pluck(:item_type).compact.sort
  end

  def item_type
    @item_type ||= params[:item_type].presence
  end

  def contributions
    @contributions ||= begin
      scope = contributions_scope.order(created_at: :desc)
      scope = scope.where(item_type: item_type) if item_type
      paginate(scope, items: CONTRIBUTIONS_PER_PAGE)
    end
  end

  def contribution_item(version)
    version.item
  rescue StandardError
    nil
  end

  def contribution_icon(version)
    CONTRIBUTION_ICONS[version.item_type] || version.item_type.to_s.gsub(/[a-z]/, "")[0, 2].presence || version.item_type.to_s[0, 2].upcase
  end

  def contribution_type_label(version)
    version.item_type.to_s.underscore.humanize
  end

  def contribution_resource_name(item)
    return if item.nil?

    item.try(:resource_name).presence || item.try(:resource_content)&.name.presence
  end

  def contribution_reference(item)
    item&.try(:verse_key)
  end

  def contribution_label(version, item = contribution_item(version))
    contribution_resource_name(item).presence ||
      contribution_reference(item).presence ||
      item&.try(:name).presence ||
      "#{contribution_type_label(version)} ##{version.item_id}"
  end

  private

  def project_resource_content_ids
    @project_resource_content_ids ||= user.user_projects.distinct.pluck(:resource_content_id).compact
  end

  def project_resource_contents
    @project_resource_contents ||= ResourceContent.where(id: project_resource_content_ids)
  end

  def filtered_resource_content_ids
    project_resource_contents.select { |rc| rc.sub_type == resource_type_filter }.map(&:id)
  end
end
