# frozen_string_literal: true

module Account
  # What the profile page (/profile) shows the signed-in user about their own account: who they
  # are, a count for each tab, and the rows of the open tab. It reads what the old profile page
  # reads (ProfilePresenter) and one list more, the resource requests the user sent.
  #
  # `tool_for` and `cms_path_for` answer with links to old pages (ProfilesHelper), so this class
  # needs no controller or view.
  class Profile
    TABS = ['downloads', 'contributions', 'resources', 'requests'].freeze
    CONTRIBUTIONS_PER_PAGE = 25
    DATE = '%-d %B %Y'

    # The query parameter each tab filters on, as the old page named them.
    FILTER_PARAMS = { 'downloads' => 'download_type', 'contributions' => 'item_type',
                      'resources' => 'resource_type', }.freeze

    Person = Data.define(:name, :initials, :email, :member_since, :about)
    Counts = Data.define(:downloads, :contributions, :resources, :requests)
    Option = Data.define(:key, :label)
    Filter = Data.define(:param, :value, :options)
    Download = Data.define(:id, :type, :name, :path, :date, :update_available)
    Contribution = Data.define(:id, :icon, :type, :label, :reference, :path, :date)
    Access = Data.define(:id, :tool, :name, :path, :approved, :date)
    Request = Data.define(:id, :title, :status, :status_label, :votes, :date)

    # The user's "about me" as the settings form edits it: plain text. Text saved by the old
    # page's editor is HTML, so its paragraphs and line breaks become line breaks.
    def self.plain_about(about)
      html = about.to_s.gsub(%r{</(p|div|li|h[1-6])>|<br\s*/?>}i, "\n")
      Nokogiri::HTML5.fragment(html).text.gsub(/\n{3,}/, "\n\n").strip
    end

    # A tag the old page's editor writes: text that has one is HTML, any other text is plain.
    HTML_TAG = %r{</?(p|br|div|span|ul|ol|li|strong|em|b|i|u|a|h[1-6]|blockquote)\b}i

    EMAIL_STATUSES = ['confirmed', 'pending', 'unconfirmed'].freeze

    # What the account settings forms start from, and the state of the email address.
    def self.settings(user)
      status = if user.pending_reconfirmation?
                 'pending'
               elsif user.confirmed?
                 'confirmed'
               else
                 'unconfirmed'
               end
      {
        first_name: user.first_name.to_s, last_name: user.last_name.to_s, about: plain_about(user.about_me),
        email: user.email, member_since: user.created_at.strftime(DATE), email_status: status,
        unconfirmed_email: user.unconfirmed_email.presence,
      }
    end

    attr_reader :user

    def initialize(user:, params:, tool_for:, cms_path_for:)
      @user = user
      @params = params
      @tool_for = tool_for
      @cms_path_for = cms_path_for
    end

    def tab
      @tab ||= tabs.include?(@params[:tab]) ? @params[:tab] : TABS.first
    end

    # The requests tab exists while the `requests` page group is on.
    def tabs
      PageGroups.enabled?(:requests) ? TABS : TABS - ['requests']
    end

    # At most 9 digits: a larger page would overflow the query's OFFSET before the range check.
    def page
      @page ||= @params[:page].nil? ? 1 : @params[:page].to_s[/\A\d{1,9}\z/].to_i
    end

    def pages
      return 1 unless tab == 'contributions'

      [(filtered_contributions.count / CONTRIBUTIONS_PER_PAGE.to_f).ceil, 1].max
    end

    def page_in_range?
      page.between?(1, pages)
    end

    def to_h
      {
        person:, counts:, tab:, filter:, page:, pages:, catalog: PageGroups.enabled?(:catalog),
        downloads: (downloads if tab == 'downloads'),
        contributions: (contributions if tab == 'contributions'),
        accesses: (accesses if tab == 'resources'),
        requests: (requests if tab == 'requests'),
      }
    end

    def person
      Person.new(
        name: [user.first_name, user.last_name].compact_blank.join(' ').presence || user.name,
        initials: user.initials, email: user.email, member_since: user.created_at.strftime('%B %Y'),
        about: about_html,
      )
    end

    def counts
      Counts.new(
        downloads: user.user_downloads.count, contributions: versions.count,
        resources: user.user_projects.count,
        requests: (own_requests.count if tabs.include?('requests')),
      )
    end

    # The open tab's filter: its query parameter, the chosen value and the values to choose from.
    # Null when the tab has none, or fewer than two values.
    def filter
      options = filter_options
      return if options.size < 2

      Filter.new(param: FILTER_PARAMS.fetch(tab), value: filter_value, options:)
    end

    private

    def filter_value
      @params[FILTER_PARAMS[tab]].presence if FILTER_PARAMS.key?(tab)
    end

    def filter_options
      case tab
      when 'downloads' then download_types.map { |type| Option.new(key: type, label: type_label(type)) }
      when 'contributions'
        contribution_types.map { |type| Option.new(key: type, label: type.underscore.humanize.pluralize) }
      when 'resources' then access_types.map { |type| Option.new(key: type, label: type.tr('-', ' ').humanize) }
      else []
      end
    end

    # The stored text as prose: editor HTML reduced to the prose tags, plain text as paragraphs.
    def about_html
      about = user.about_me.to_s.strip
      return if about.empty?

      unless about.match?(HTML_TAG)
        about = ActionController::Base.helpers.simple_format(ERB::Util.html_escape(about), {}, sanitize: false)
      end
      Content::Prose.sanitize(about).presence
    end

    def type_label(resource_type)
      Catalog::Taxonomy.type(resource_type)&.label || resource_type.to_s.tr('-', ' ').humanize
    end

    def date(time)
      time&.strftime(DATE)
    end

    # ---- Downloads: the files the user downloaded, newest first.

    def download_types
      user.user_downloads.joins(:downloadable_resource).distinct
        .pluck('downloadable_resources.resource_type').compact.sort
    end

    def downloads
      scope = user.user_downloads.includes(:downloadable_resource).order(Arel.sql('last_download_at DESC NULLS LAST'))
      if filter_value
        scope = scope.joins(:downloadable_resource).where(downloadable_resources: { resource_type: filter_value })
      end
      scope.map { |download| download_row(download) }
    end

    def download_row(download)
      resource = download.downloadable_resource
      Download.new(
        id: download.id, type: resource && type_label(resource.resource_type), name: resource&.name || 'Resource',
        path: (resource_path(resource) if resource&.published), date: date(download.last_download_at),
        update_available: updated_since?(resource, download),
      )
    end

    def resource_path(resource)
      Rails.application.routes.url_helpers.detail_resources_path(resource.resource_type, resource.to_param)
    end

    def updated_since?(resource, download)
      return false unless resource && download.last_download_at

      resource.updated_at > download.last_download_at
    end

    # ---- Contributions: the changes the user made to the data (PaperTrail versions), a page at a time.

    def versions
      PaperTrail::Version.where(user_id: user.id)
    end

    def contribution_types
      versions.distinct.pluck(:item_type).compact.sort
    end

    def filtered_contributions
      filter_value ? versions.where(item_type: filter_value) : versions
    end

    def contributions
      filtered_contributions.order(created_at: :desc).offset((page - 1) * CONTRIBUTIONS_PER_PAGE)
        .limit(CONTRIBUTIONS_PER_PAGE).map { |version| contribution_row(version) }
    end

    def contribution_row(version)
      item = contribution_item(version)
      type = version.item_type.to_s.underscore.humanize
      reference = item&.try(:verse_key).presence
      label = contribution_label(item, reference) || "#{type} ##{version.item_id}"
      Contribution.new(
        id: version.id, icon: contribution_icon(version.item_type.to_s), type:, label:,
        reference: (reference unless reference == label), path: item && @cms_path_for.call(item),
        date: date(version.created_at),
      )
    end

    def contribution_label(item, reference)
      return unless item

      item.try(:resource_name).presence || item.try(:resource_content)&.name.presence || reference ||
        item.try(:name).presence
    end

    # The changed row, or nil when it is gone or its class no longer exists.
    def contribution_item(version)
      version.item
    rescue StandardError
      nil
    end

    def contribution_icon(item_type)
      ProfilePresenter::CONTRIBUTION_ICONS[item_type] || item_type.gsub(/[a-z]/, '')[0, 2].presence ||
        item_type[0, 2].upcase
    end

    # ---- Edit access: the resources the user asked to edit with the contributor tools.

    # The resource rows live in the content database, so they are read in a second query.
    def project_contents
      @project_contents ||= ResourceContent.where(
        id: user.user_projects.distinct.pluck(:resource_content_id).compact,
      ).to_a
    end

    def access_types
      project_contents.filter_map(&:sub_type).uniq.sort
    end

    def accesses
      scope = user.user_projects.includes(:resource_content).order(approved: :desc, updated_at: :desc)
      if filter_value
        ids = project_contents.select { |content| content.sub_type == filter_value }.map(&:id)
        scope = scope.where(resource_content_id: ids)
      end
      scope.map { |project| access_row(project) }
    end

    def access_row(project)
      content = project.resource_content
      tool = @tool_for.call(content)
      Access.new(
        id: project.id, tool: (tool[:label].presence if content), name: content&.name || 'Resource',
        path: (tool[:url] if project.approved?), approved: project.approved?, date: date(project.updated_at),
      )
    end

    # ---- Requests: the visible resource requests the user sent, newest first, with their votes.

    def own_requests
      ResourceRequest.visible.where(user_id: user.id)
    end

    def requests
      own_requests.left_joins(:votes).group(:id).order(created_at: :desc)
        .select('resource_requests.*, COUNT(resource_request_votes.id) AS votes_count')
        .map do |request|
        Request.new(id: request.id, title: request.title, status: request.status,
                    status_label: request.status_label, votes: request.votes_count, date: date(request.created_at),)
      end
    end
  end
end
