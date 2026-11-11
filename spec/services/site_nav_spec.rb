require 'clone_helper'

RSpec.describe SiteNav do
  # Tools that exist only where the QUL scripts are installed (ToolsHelper#internal_developer_tools)
  let(:internal_titles) { ['Segment pipeline', 'Add reciter audio'] }
  let(:tools) do
    Class.new do
      include Rails.application.routes.url_helpers
      include ApplicationHelper
      include ToolsHelper
    end.new.developer_tools
  end

  it 'refuses a link with an icon the frontend has no component for' do
    expect { described_class::Link.new(label: 'Tool', href: '/tool', icon: 'no-such-icon') }
      .to raise_error(ArgumentError, /unknown nav icon "no-such-icon"/)
    expect(described_class::Link.new(label: 'Tool', href: '/tool', icon: 'palette').icon).to eq('palette')
  end

  it 'gives every tool entry an icon from ICONS and a description' do
    entries = described_class::ContributeTools::GROUPS.values.flat_map(&:values)

    expect(entries.map(&:first)).to all(be_in(described_class::ICONS))
    expect(entries.map(&:last)).to all(be_present)
  end

  it 'has no stale tool entry: each title is the title of a tool' do
    titles = described_class::ContributeTools::GROUPS.values.flat_map(&:keys)
    known = tools.map(&:title) + (Rails.application.config.x.qul_scripts_available ? [] : internal_titles)

    expect(titles - known).to be_empty
  end

  it 'lists a tool without an entry under the fallback group' do
    extra = Struct.new(:title, :url).new('New tool', '/new_tool')
    groups = described_class::ContributeTools.grouped([*tools, extra])

    expect(groups.last).to eq([described_class::ContributeTools::FALLBACK_GROUP, [[extra, nil, nil]]])
  end
end
