# frozen_string_literal: true
# == Schema Information
#
# Table name: audio_sections
#
#  id         :bigint           not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

module Audio
  class Section < QuranApiRecord
    include NameTranslateable
  end
end
