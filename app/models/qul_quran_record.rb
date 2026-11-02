class QulQuranRecord < ApplicationRecord
  include Utils::StrongMemoize
  self.abstract_class = true
 
  self.establish_connection(
    if Rails.env.development? then :qul_quran_content_db_dev
    elsif Rails.env.test? then :qul_quran_content_db_test
    else :qul_quran_content_db
    end
  )

  CDN_HOST = ENV['CDN_HOST']
  WORDS_CDN = "#{CDN_HOST}/qul/images/w"
  AYAH_CDN = "#{CDN_HOST}/qul/images/ayah"
  FONTS_CDN = "#{CDN_HOST}/qul/fonts"

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