# == Schema Information
#
# Table name: reciters
#
#  id                :integer          not null, primary key
#  bio               :text
#  cover_image       :string
#  name              :string
#  profile_picture   :string
#  recitations_count :integer          default(0)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#

class Reciter < QuranApiRecord
  has_many :translated_names, as: :resource

  has_many :audio_recitations, class_name: 'Audio::Recitation'
  has_many :verse_recitations, class_name: 'Recitation'

  def update_recitation_count
    update_column :recitations_count, audio_recitations.size + verse_recitations.size
  end

  def profile_picture_url
    if profile_picture.present?
      "#{CDN_HOST}/#{profile_picture}"
    end
  end

  def cover_url
    if cover_image.present?
      "#{CDN_HOST}/#{cover_image}"
    end
  end
end
