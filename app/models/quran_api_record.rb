class QuranApiRecord < ApplicationRecord
  include Utils::StrongMemoize
  self.abstract_class = true
  self.establish_connection Rails.env.development? ? :quran_api_db_dev : :quran_api_db

  CDN_HOST = 'https://static-cdn.tarteel.ai'
  WORDS_CDN = "#{CDN_HOST}/qul/images/w"
  AYAH_CDN = "#{CDN_HOST}/qul/images/ayah"

  def toggle_approve!
    update_attribute :approved, !self.approved?
  end

  def self.ransackable_associations(auth_object = nil)
    ['translated_name']
  end

  def self.ransackable_attributes(auth_object = nil)
    column_names
  end
end