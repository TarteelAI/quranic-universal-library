# == Schema Information
#
# Table name: qirat_types
#
#  id                :bigint           not null, primary key
#  description       :text
#  name              :string
#  recitations_count :integer          default(0)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#

class QiratType < QuranApiRecord
  has_many :audio_recitations, class_name: 'Audio::Recitation'
  has_many :verse_recitations, class_name: 'Recitation'
  has_many :mushafs

  def update_recitation_count
    update_column :recitations_count, audio_recitations.size + verse_recitations.size
  end
end
