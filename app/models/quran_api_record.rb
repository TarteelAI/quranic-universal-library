class QuranApiRecord < ApplicationRecord
  self.abstract_class = true
  self.establish_connection Rails.env.development? ? :quran_api_db_dev : :quran_api_db

  CDN_HOST = 'https://static.qurancdn.com'
  WORDS_CDN = 'https://static-cdn.tarteel.ai/qul/images/w'
  AYAH_CDN = 'https://static-cdn.tarteel.ai/qul/images/ayah'


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