# == Schema Information
#
# Table name: recitation_styles
#
#  id                :integer          not null, primary key
#  arabic            :string
#  description       :text
#  name              :string
#  recitations_count :integer          default(0)
#  slug              :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_recitation_styles_on_slug  (slug)
#

class RecitationStyle < QuranApiRecord
  include NameTranslateable

  has_many :audio_recitations, class_name: 'Audio::Recitation'
  has_many :verse_recitations, class_name: 'Recitation'

  def update_recitation_count
    update_column :recitations_count, audio_recitations.size + verse_recitations.size
  end
end
