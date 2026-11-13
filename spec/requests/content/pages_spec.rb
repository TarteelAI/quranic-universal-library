# frozen_string_literal: true

require 'clone_helper'

RSpec.describe 'FAQ, credits and the tools overview (/faq, /credits, /tools)', type: :request do
  let(:hostile) do
    '<p onclick="steal()">Read <a href="javascript:alert(1)" onmouseover="x()">this</a> and ' \
      '<a href="https://example.com/x" target="_blank">that</a>.</p><script>alert(1)</script>' \
      '<img src="x" onerror="alert(2)"><iframe src="https://example.com"></iframe><ul><li><strong>kept</strong></li></ul>'
  end
  let(:code_contributors) do
    [{ login: 'octocat', name: 'octocat', avatar_url: 'https://avatars.githubusercontent.com/u/1',
       html_url: 'https://github.com/octocat', contributions: 12, type: 'User', }]
  end

  before { allow(GithubService).to receive(:fetch_contributors).and_return(code_contributors) }

  # No script, image, frame, event handler or javascript: link is left; the prose is.
  def expect_harmless(html)
    fragment = Nokogiri::HTML5.fragment(html)
    expect(fragment.css('script, img, iframe')).to be_empty
    expect(fragment.xpath('.//@*').map { |attribute| [attribute.name, attribute.value] })
      .to eq([['href', 'https://example.com/x']])
    expect(fragment.text).to eq('Read this and that.kept')
  end

  def head
    Nokogiri::HTML(response.body)
  end

  describe 'with the content page group on', page_groups: ['content'] do
    it 'renders the published FAQ items in order, server-rendered' do
      SsrServer.with_ssr { get '/faq' }

      expect(response).to have_http_status(:ok)
      expect(controller).to be_a(Content::PagesController)
      expect(inertia).to render_component('content/FaqPage')
      published = Faq.published.to_a
      expect(published).not_to be_empty
      expect(inertia.props[:items].pluck(:id)).to eq(published.map(&:id))
      expect(inertia.props[:items].first).to include(question: published.first.question)
      app = Nokogiri::HTML(response.body).at('#app[data-server-rendered="true"]')
      expect(app.css("#faq-#{published.first.id}")).to be_present
    end

    it 'reduces an FAQ answer with editor markup to formatted text' do
      faq = Faq.create!(question: 'Hostile?', answer: hostile, published: true, position: -1)
      Faq.create!(question: 'Draft', answer: '<p>x</p>', published: false, position: -2)

      get '/faq'

      expect(inertia.props[:items].first).to include(id: faq.id, question: 'Hostile?')
      expect(inertia.props[:items].pluck(:question)).not_to include('Draft')
      expect_harmless(inertia.props[:items].first[:answer])
    end

    it 'renders the credits: organizations, acknowledgements and code contributors' do
      SsrServer.with_ssr { get '/credits' }

      expect(response).to have_http_status(:ok)
      expect(inertia).to render_component('content/CreditsPage')
      expect(inertia.props[:organizations].pluck(:name)).to eq(Contributor.published.order(:id).pluck(:name))
      expect(inertia.props[:organizations]).to all(include(:logoUrl))
      acknowledgements = inertia.props[:acknowledgements].map(&:deep_symbolize_keys)
      expect(acknowledgements.size).to eq(controller.helpers.contributors.size)
      expect(acknowledgements.first).to eq(
        entities: [{ name: 'Dr. Amin Anane', url: 'https://github.com/aminanan' }],
        description: 'For developing and providing the DigitalKhatt fonts.',
      )
      everyayah = acknowledgements.find { |item| item[:entities].size == 2 }
      expect(everyayah[:entities].pluck(:name)).to eq(['EveryAyah.com', 'QuranicAudio.com'])
      expect(acknowledgements.flat_map { |item| item[:entities] }).to include(name: 'Sami Rifai', url: nil)
      expect(inertia.props[:codeContributors].map(&:deep_symbolize_keys)).to eq(
        [{ login: 'octocat', url: 'https://github.com/octocat', avatarUrl: 'https://avatars.githubusercontent.com/u/1',
           contributions: 12, }],
      )
      app = Nokogiri::HTML(response.body).at('#app[data-server-rendered="true"]')
      expect(app.text).to include('Dr. Amin Anane', 'octocat')
    end

    it 'reduces a credits entry with editor markup to formatted text, and leaves out unpublished ones' do
      contributor = Contributor.create!(name: 'Hostile', url: 'https://example.com', description: hostile)
      Contributor.create!(name: 'Hidden', description: 'x', published: false)

      get '/credits'

      organization = inertia.props[:organizations].find { |item| item[:name] == 'Hostile' }
      expect(organization).to include(url: contributor.url, logoUrl: nil)
      expect(inertia.props[:organizations].pluck(:name)).not_to include('Hidden')
      expect_harmless(organization[:description])
    end

    it 'lists every contribution tool under a named group, linking to its old page' do
      SsrServer.with_ssr { get '/tools' }

      expect(response).to have_http_status(:ok)
      expect(inertia).to render_component('content/ToolsPage')
      groups = inertia.props[:groups]
      expect(groups.pluck(:heading)).to all(be_in(SiteNav::ContributeTools::GROUPS.keys))
      expect(groups.pluck(:summary)).to all(be_present)

      tools = controller.helpers.developer_tools
      listed = groups.flat_map { |group| group[:tools] }
      expect(listed.map { |tool| [tool[:label], tool[:href], tool[:description]] })
        .to match_array(tools.map { |tool| [tool.title, tool.url, tool.description] })
      expect(listed.pluck(:icon)).to all(be_in(SiteNav::ICONS))

      app = Nokogiri::HTML(response.body).at('#app[data-server-rendered="true"]')
      expect(app.css('a[href="/mushaf_layouts"]')).to be_present
    end

    it 'puts a title, description and canonical link in the head of each page' do
      { '/faq' => 'FAQ', '/credits' => 'Credits', '/tools' => 'Contribution tools' }.each do |path, title|
        get path

        expect(head.at('title').text).to eq("#{title} - QUL"), path
        expect(head.at('meta[name="description"]')['content']).to be_present, path
        expect(head.at('link[rel="canonical"]')['href']).to eq("https://qul.tarteel.ai#{path}"), path
      end
    end
  end

  describe 'with the content page group off', page_groups: [] do
    it 'serves the old pages' do
      ['/faq', '/credits', '/tools'].each do |path|
        get path

        expect(response).to have_http_status(:ok), path
        expect(controller).to be_a(CommunityController), path
        expect(response.body).not_to include('data-page='), path
      end
    end
  end
end
