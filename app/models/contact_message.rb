# == Schema Information
#
# Table name: contact_messages
#
#  id         :bigint           not null, primary key
#  detail     :text
#  email      :string
#  name       :string
#  subject    :string
#  url        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class ContactMessage < ApplicationRecord
end
