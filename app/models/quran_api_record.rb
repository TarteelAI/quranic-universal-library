class QuranApiRecord < ActiveRecord::Base
  self.abstract_class = true
  self.establish_connection Rails.env.development? ? :quran_api_db_dev : :quran_api_db

  CDN_HOST = 'https://static.qurancdn.com'

  def toggle_approve!
    update_attribute :approved, !self.approved?
  end
end