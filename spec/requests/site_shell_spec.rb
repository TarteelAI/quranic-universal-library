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
      expect(props[:nav].keys).to eq(%i[menus search footer])
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
      tools = menus.last[:groups].first[:links]
      expect(tools.pluck(:href)).to eq(controller.helpers.developer_tools.map(&:url))
      expect(menus.first[:groups].first[:links].pluck(:href)).to eq(Catalog::Taxonomy.types.map { |t| "/resources/#{t.key}" })
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
  end
end
