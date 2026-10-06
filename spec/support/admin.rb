# frozen_string_literal: true

# Sign-in helpers for CMS request specs.
#
#   RSpec.describe 'CMS riwayat', type: :request do
#     before { sign_in_admin }
#     it { get '/cms/riwayat'; expect(response).to have_http_status(:ok) }
#   end
module AdminSpecHelpers
  def create_admin!(email: 'spec-admin@cms.test')
    User.find_by(email: email) || User.create!(
      email: email,
      first_name: 'Spec',
      last_name: 'Admin',
      password: 'spec-password-123',
      approved: true,
      role: 'super_admin',
      confirmed_at: Time.current
    )
  end

  def sign_in_admin
    host! 'localhost' # config/initializers/hosts.rb blocks www.example.com
    sign_in create_admin!
  end
end

RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include AdminSpecHelpers, type: :request
end
