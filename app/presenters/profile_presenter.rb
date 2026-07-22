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

  def tab
    @tab ||= params[:tab] == "contributions" ? "contributions" : "downloads"
  end

  def downloads?
    tab == "downloads"
  end

  def contributions?
    tab == "contributions"
  end

  def downloads
    @downloads ||= user.user_downloads
                       .includes(:downloadable_resource)
                       .order(Arel.sql("last_download_at DESC NULLS LAST"))
  end

  def downloads_count
    @downloads_count ||= user.user_downloads.count
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
end
