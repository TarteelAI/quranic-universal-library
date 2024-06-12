# == Schema Information
#
# Table name: word_tajweed_positions
#
#  id         :bigint           not null, primary key
#  audio      :string
#  location   :string
#  positions  :jsonb
#  rule       :string
#  style      :jsonb
#  word_group :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class WordTajweedPosition < ApplicationRecord
end
