require 'clone_helper'

RSpec.describe 'Inertia sample page (development only)', type: :request do
  let(:sample_path) { '/__dev/inertia_sample' }

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  def fake_user
    User.new(email: 'spec-reader@example.test', first_name: 'Spec', last_name: 'Reader', password: 'spec-password').tap do |user|
      user.skip_confirmation!
      user.save!
    end
  end

  describe 'GET the page' do
    before { get sample_path }

    it 'renders the component with its props and shared props' do
      expect(response).to have_http_status(:ok)
      expect(inertia).to render_component('dev/InertiaSample')
      expect(inertia).to have_props(heading: 'Inertia sample page', signedIn: false)
      expect(inertia).to have_deferred_props(:publishedResourceCount)
    end

    it 'puts the server-managed meta tags in the HTML without SSR' do
      html = Nokogiri::HTML(response.body)

      expect(html.at('title').text).to eq('Inertia sample - QUL')
      expect(html.at('meta[name="description"]')['content']).to start_with('A development page')
      expect(html.at('link[rel="canonical"]')['href']).to eq("https://qul.tarteel.ai#{sample_path}")
      expect(html.at('meta[property="og:title"]')['content']).to eq('Inertia sample - QUL')
      json_ld = JSON.parse(html.at('script[type="application/ld+json"]').text)
      expect(json_ld).to include('@type' => 'WebPage', 'url' => "https://qul.tarteel.ai#{sample_path}")
    end

    it 'loads with its own layout: no Turbo, and old-page Turbo visits reload' do
      html = Nokogiri::HTML(response.body)

      expect(html.at('meta[name="turbo-visit-control"]')['content']).to eq('reload')
      expect(html.at('script[data-page="app"][type="application/json"]')).to be_present
      expect(html.css('script[src]').map { |s| s['src'] }).to all(include('/vite-test/'))
    end
  end

  it 'loads the deferred prop on the follow-up request' do
    get sample_path
    inertia_load_deferred_props

    expect(inertia).to have_props(publishedResourceCount: DownloadableResource.published.count)
  end

  it 'answers the useHttp JSON request with the shared props shape' do
    get "#{sample_path}/ping"

    expect(response.parsed_body).to eq('signedIn' => false)
  end

  describe 'CSRF with protect_from_forgery and xsrf_cookie_refresh: :lazy' do
    it 'rejects an Inertia POST without a token' do
      with_forgery_protection do
        post sample_path, headers: { 'X-Inertia' => 'true' }
      end

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'accepts the XSRF-TOKEN cookie sent back as X-XSRF-TOKEN, and keeps the cookie on later GETs' do
      with_forgery_protection do
        get sample_path
        token = cookies['XSRF-TOKEN']
        expect(token).to be_present

        get sample_path
        expect(response.headers['Set-Cookie'].to_s).not_to include('XSRF-TOKEN')

        post sample_path, headers: { 'X-Inertia' => 'true', 'X-XSRF-TOKEN' => token }
      end

      expect(response).to redirect_to(sample_path)
      follow_redirect!
      expect(inertia).to have_flash(notice: 'The form was received.')
    end
  end

  describe 'Devise across the old and new pages' do
    it 'returns to the Inertia page after signing in' do
      user = fake_user

      get '/users/sign_in', params: { user_return_to: sample_path }
      post '/users/sign_in', params: { user: { email: user.email, password: 'spec-password' } }

      expect(response).to redirect_to(sample_path)
      follow_redirect!
      expect(inertia).to have_props(signedIn: true)
    end

    it 'signs out with the plain form post the page renders, and lands on the old home page' do
      user = fake_user
      post '/users/sign_in', params: { user: { email: user.email, password: 'spec-password' } }

      delete '/users/sign_out'

      expect(response).to redirect_to('/')
      follow_redirect!
      expect(response).to have_http_status(:ok)
      get sample_path
      expect(inertia).to have_props(signedIn: false)
    end
  end

  describe 'redirects behind the proxy headers nginx sets (Host, X-Forwarded-For)' do
    let(:proxy_headers) { { 'X-Inertia' => 'true', 'X-Forwarded-For' => '203.0.113.7' } }

    it 'keeps a redirect to a path on this host as an Inertia redirect' do
      host! 'qul.tarteel.ai'
      post sample_path, headers: proxy_headers

      expect(response).to have_http_status(:found)
      expect(response.headers['Location']).to eq("http://qul.tarteel.ai#{sample_path}")
      expect(response.headers).not_to have_key('X-Inertia-Location')
    end

    it 'turns a full https URL into a full page visit when the request reached Rails as http' do
      app = ->(_env) { [302, { 'Location' => "https://qul.tarteel.ai#{sample_path}" }, []] }
      env = Rack::MockRequest.env_for("http://qul.tarteel.ai#{sample_path}", method: 'POST',
                                      'HTTP_X_INERTIA' => 'true', 'HTTP_X_FORWARDED_FOR' => '203.0.113.7')

      status, headers, = InertiaRails::Middleware.new(app).call(env)

      expect(status).to eq(409)
      expect(headers['X-Inertia-Location']).to eq("https://qul.tarteel.ai#{sample_path}")
    end
  end
end
