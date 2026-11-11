# frozen_string_literal: true

# The header menus and the footer links of the new pages (the v7 site shell). Each link says
# whether a new page serves it: `inertia` links are Inertia visits, the rest are plain links
# to the old pages (docs, tools, the home page), which load in full.
class SiteNav
  # The icon names a link can carry (the frontend maps each to a lucide icon): the contribution
  # tools (SiteNav::ContributeTools) and the help links of the Contribute menu.
  ICONS = %w[
    languages case-sensitive book-open-text info layout-panel-top palette type audio-waveform timer
    scissors workflow mic whole-word split sprout tags network repeat copy list-tree layers git-compare
    file-diff audio-lines columns hash book-open circle-help award
  ].freeze

  Link = Data.define(:label, :href, :description, :category, :icon, :external, :inertia) do
    def initialize(label:, href:, description: nil, category: nil, icon: nil, external: false, inertia: false)
      # The frontend has a component for each name in ICONS only
      raise ArgumentError, "unknown nav icon #{icon.inspect} for #{label}" if icon && ICONS.exclude?(icon)

      super
    end
  end
  # `tools` marks a group of contribution tools (the Contribute menu's tool groups), so other
  # parts of the page can tell the tools from the other links.
  Group = Data.define(:heading, :links, :wide, :tools) do
    def initialize(heading:, links:, wide: false, tools: false)
      super
    end
  end
  # A `dense` menu shows its groups in three columns of one-line rows and its aside as a row of
  # links under them.
  Menu = Data.define(:label, :href, :overview, :inertia, :groups, :aside, :dense) do
    def initialize(label:, href:, overview:, inertia:, groups:, aside:, dense: false)
      super
    end
  end

  REPO_URL = 'https://github.com/TarteelAI/quranic-universal-library'
  REQUEST_URL = "#{REPO_URL}/issues/new?template=resource_request.yml".freeze
  DISCORD_URL = 'https://t.zip/discord?utm_source=qul%20header&utm_campaign=qul'

  attr_reader :home, :menus, :footer, :search, :request

  # `tools` are the contributor tools (ToolsHelper#developer_tools): anything with a title and a url.
  def initialize(tools:)
    @catalog = PageGroups.enabled?(:catalog)
    @apps = PageGroups.enabled?(:apps)
    @home = Link.new(label: 'Home', href: '/', inertia: PageGroups.enabled?(:home))
    @tools = tools
    @request = Link.new(label: 'Request a resource', href: REQUEST_URL, external: true,
                        description: 'Ask for a translation, tafsir or recitation that is missing.')
    @menus = [resources_menu, docs_menu, developers_menu, contribute_menu]
    @footer = footer_groups
    @search = catalog_link('Search resources', '/resources')
  end

  private

  def routes
    Rails.application.routes.url_helpers
  end

  def catalog_link(label, href, **options)
    Link.new(label:, href:, inertia: @catalog, **options)
  end

  def type_link(type, **options)
    catalog_link(type.title, "/resources/#{type.key}", **options)
  end

  def doc_link(label, slug, **options)
    Link.new(label:, href: routes.docs_path(slug), **options)
  end

  def github_link
    Link.new(label: 'GitHub', href: REPO_URL, external: true)
  end

  # The apps directory has no old page, so there is no link to it while its group is off.
  def apps_links
    @apps ? [Link.new(label: 'Apps built with QUL', href: '/apps', inertia: true)] : []
  end

  def resources_menu
    types = Catalog::Taxonomy.types.map do |type|
      type_link(type, description: type.summary, category: type.category.key)
    end
    fix_links = [
      Link.new(label: 'Fix a translation', href: routes.translations_path),
      Link.new(label: 'All contribution tools', href: routes.tools_path)
    ]
    jump_to = [
      catalog_link('All resources', '/resources'),
      catalog_link('Compare mushaf layouts', '/resources/mushaf-layout'),
      doc_link('How to download', 'downloading-data')
    ]
    Menu.new(
      label: 'Resources', href: '/resources', overview: 'Browse all resources', inertia: @catalog,
      groups: [Group.new(heading: 'Resource types', links: types, wide: true)],
      aside: [
        Group.new(heading: 'Jump to', links: jump_to),
        Group.new(heading: 'Cannot find it?', links: [@request]),
        Group.new(heading: 'Spot a mistake?', links: fix_links)
      ]
    )
  end

  def docs_menu
    links = [
      doc_link('Getting started', 'getting-started', description: 'Find a resource, download it and use it.'),
      doc_link('Data model', 'data-model', description: 'How resources, files and Quran data fit together.'),
      doc_link('Resource guides', 'resource-guides-index', description: 'One guide for each resource type.'),
      doc_link('Tutorials', 'tutorials', description: 'Build a feature with each resource type, step by step.')
    ]

    Menu.new(
      label: 'Docs', href: routes.docs_index_path, overview: 'All docs', inertia: false,
      groups: [Group.new(heading: 'Learn', links:, wide: true)], aside: []
    )
  end

  def developers_menu
    links = [
      doc_link('API', 'api', description: 'Get Quran data over HTTP as JSON.'),
      doc_link('Run QUL on your computer', 'project-setup',
               description: 'Set up the code and a database for local work.'),
      doc_link('Contribute code', 'contribute-code', description: 'How to send a change to the QUL code.')
    ]

    Menu.new(
      label: 'Developers', href: routes.docs_path('api'), overview: 'API docs', inertia: false,
      groups: [Group.new(heading: 'Build with QUL', links:)],
      aside: [Group.new(heading: 'Source code', links: [github_link])]
    )
  end

  def contribute_menu
    tools = ContributeTools.grouped(@tools).map do |heading, entries|
      links = entries.map { |tool, icon, text| Link.new(label: tool.title, href: tool.url, icon:, description: text) }
      Group.new(heading:, links:, tools: true)
    end
    about = [
      doc_link('How to contribute data', 'contribute-data', icon: 'book-open',
                                                            description: 'A guide to fixing and adding data.'),
      Link.new(label: 'FAQ', href: routes.faq_path, icon: 'circle-help', description: 'Answers to common questions.'),
      Link.new(label: 'Credits', href: routes.credits_path, icon: 'award', description: 'Who made the data and tools.')
    ]
    help = [@request, Link.new(label: 'Changelog', href: routes.change_logs_path)]
    community = [*apps_links, Link.new(label: 'Discord', href: DISCORD_URL, external: true), github_link]

    Menu.new(
      label: 'Contribute', href: routes.tools_path, overview: 'All contribution tools', inertia: false, dense: true,
      groups: [*tools, Group.new(heading: 'About contributing', links: about)],
      aside: [
        Group.new(heading: 'Help improve the data', links: help),
        Group.new(heading: 'Community', links: community)
      ]
    )
  end

  def footer_groups
    resources = [
      catalog_link('All resources', '/resources'),
      *%w[translation tafsir recitation mushaf-layout].map { |key| type_link(Catalog::Taxonomy.type(key)) }
    ]
    docs = [
      doc_link('Getting started', 'getting-started'),
      doc_link('Resource guides', 'resource-guides-index'),
      doc_link('API', 'api'),
      Link.new(label: 'All docs', href: routes.docs_index_path)
    ]
    contribute = [
      Link.new(label: 'Contribution tools', href: routes.tools_path),
      Link.new(label: 'FAQ', href: routes.faq_path),
      Link.new(label: 'Credits', href: routes.credits_path)
    ]
    community = [
      *apps_links,
      github_link,
      Link.new(label: 'Discord', href: DISCORD_URL, external: true),
      Link.new(label: 'Tarteel', href: 'https://tarteel.ai', external: true)
    ]

    [
      Group.new(heading: 'Resources', links: resources),
      Group.new(heading: 'Docs', links: docs),
      Group.new(heading: 'Contribute', links: contribute),
      Group.new(heading: 'Community', links: community)
    ]
  end
end
