require 'clone_helper'

RSpec.describe 'Site shell of the new pages (shared props, flash, theme)', type: :request do
  let(:page_path) { '/resources/translation' }

  def create_user
    User.new(email: 'spec-shell@example.test', first_name: 'Spec', last_name: 'Shell', password: 'spec-password').tap do |user|
      user.skip_confirmation!
      user.save!
    end
  end

  def props
    inertia.props.to_h.deep_symbolize_keys
  end

  def all_links(nav)
    nav[:menus].flat_map { |menu| [menu, *(menu[:groups] + menu[:aside]).flat_map { |group| group[:links] }] } +
      nav[:footer].flat_map { |group| group[:links] } + [nav[:search]]
  end

  describe 'with the catalog page group on', page_groups: %w[catalog] do
    it 'sends a signed-out visitor no user' do
      get page_path

      expect(props[:auth]).to eq(user: nil)
    end

    it 'sends a signed-in user only the initials and name the header shows' do
      user = create_user
      post '/users/sign_in', params: { user: { email: user.email, password: 'spec-password' } }
      get page_path

      expect(props[:auth]).to eq(user: { initials: 'SS', name: 'Spec' })
    end

    it 'sends the navigation once: on the first load, not on later Inertia visits that already have it' do
      get page_path
      expect(props[:nav].keys).to eq(%i[home menus search footer request])
      expect(props[:nav][:request]).to include(href: SiteNav::REQUEST_URL, external: true)
      expect(inertia).to have_once_props(nav: { prop: 'nav' })

      get '/resources/tafsir', headers: { 'X-Inertia' => 'true', 'X-Inertia-Version' => InertiaRails.configuration.version.to_s,
                                          'X-Inertia-Except-Once-Props' => 'nav' }
      expect(inertia).to render_component('catalog/TypePage')
      expect(inertia).to have_props(auth: { user: nil })
      expect(inertia).to have_no_prop(:nav)
    end

    it 'has the four header menus, with the contributor tools under Contribute' do
      get page_path
      menus = props[:nav][:menus]

      expect(menus.pluck(:label)).to eq(%w[Resources Docs Developers Contribute])
      expect(menus.pluck(:dense)).to eq([false, false, false, true])
      tools = menus.last[:groups][0...-1].flat_map { |group| group[:links] }
      expect(tools.pluck(:href)).to match_array(controller.helpers.developer_tools.map(&:url))
      expect(menus.first[:groups].first[:links].pluck(:href)).to eq(Catalog::Taxonomy.types.map { |t| "/resources/#{t.key}" })
    end

    it 'groups the contributor tools, each with an icon and a one-line description' do
      get page_path
      contribute = props[:nav][:menus].last

      # No tool falls back to the group without icons: every tool has its entry in ContributeTools
      expect(contribute[:groups].pluck(:heading)).to eq([*SiteNav::ContributeTools::GROUPS.keys, 'About contributing'])
      links = contribute[:groups].flat_map { |group| group[:links] }
      expect(links).to all(include(icon: be_in(SiteNav::ICONS), description: be_present))
      expect(contribute[:groups].last[:links].pluck(:href)).to eq(['/docs/contribute-data', '/faq', '/credits'])
    end

    it 'marks the contributor tool groups, and only those, as tools' do
      get page_path
      nav = props[:nav]
      contribute = nav[:menus].last

      expect(contribute[:groups].pluck(:tools)).to eq([true] * SiteNav::ContributeTools::GROUPS.size + [false])
      others = nav[:menus][0...-1].flat_map { |menu| menu[:groups] + menu[:aside] } + contribute[:aside] + nav[:footer]
      expect(others.pluck(:tools)).to all(be(false))
    end

    it 'puts the request form, the changelog and the community links under the Contribute tools' do
      get page_path
      aside = props[:nav][:menus].last[:aside]

      expect(aside.pluck(:heading)).to eq(['Help improve the data', 'Community'])
      expect(aside.first[:links].pluck(:href)).to eq([SiteNav::REQUEST_URL, '/change_logs'])
      expect(aside.last[:links].pluck(:label)).to eq(%w[Discord GitHub])
    end

    it 'adds a "Spot a mistake?" group to the Resources menu, linking the translation tool and all tools' do
      get page_path
      group = props[:nav][:menus].first[:aside].find { |g| g[:heading] == 'Spot a mistake?' }

      expect(group[:links].pluck(:label, :href)).to eq([['Fix a translation', '/translations'],
                                                         ['All contribution tools', '/tools']])
      expect(group[:links].pluck(:inertia)).to all(be(false))
    end

    it 'marks only the catalog pages as Inertia visits' do
      get page_path
      links = all_links(props[:nav])

      inertia_hrefs = links.select { |link| link[:inertia] }.pluck(:href).uniq
      expect(inertia_hrefs).to all(match(%r{\A/resources(/[a-z-]+)?\z}))
      expect(links.reject { |link| link[:inertia] }.pluck(:href)).to all(satisfy { |href| !href.start_with?('/resources') })
    end

    it 'shows a notice set before a redirect to a new page once' do
      user = create_user
      get '/users/sign_in', params: { user_return_to: page_path }
      post '/users/sign_in', params: { user: { email: user.email, password: 'spec-password' } }

      expect(response).to redirect_to(page_path)
      follow_redirect!
      expect(inertia).to have_flash(notice: 'Signed in successfully.')

      get page_path
      expect(inertia).to have_no_flash(:notice)
    end

    it 'sets the theme before the first paint: a stored choice, else the system setting' do
      get page_path
      script = Nokogiri::HTML(response.body).css('head script:not([src])').map(&:text).find { |s| s.include?('qul-theme') }

      expect(script).to include("localStorage.getItem('qul-theme')", 'prefers-color-scheme: dark')
    end
  end

  describe 'with the catalog page group off', page_groups: [] do
    it 'links the catalog as old pages, with full page loads' do
      get '/__dev/inertia_sample'

      expect(all_links(props[:nav]).pluck(:inertia)).to all(be(false))
    end

    it 'has the same Contribute menu, without the apps link' do
      get '/__dev/inertia_sample'
      contribute = props[:nav][:menus].last

      expect(contribute[:dense]).to be(true)
      expect(contribute[:aside].last[:links].pluck(:label)).to eq(%w[Discord GitHub])
      expect(props[:nav][:menus].first[:aside].pluck(:heading)).to include('Spot a mistake?')
    end
  end

  describe 'with the apps page group on', page_groups: %w[catalog apps] do
    it 'links the apps directory from the Contribute menu' do
      get page_path

      community = props[:nav][:menus].last[:aside].last[:links]
      expect(community.pluck(:label, :href).first).to eq(['Apps built with QUL', '/apps'])
    end
  end
end
