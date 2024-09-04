# == Schema Information
#
# Table name: faqs
#
#  id         :bigint           not null, primary key
#  answer     :text
#  position   :integer
#  published  :boolean          default(FALSE)
#  question   :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_faqs_on_position_and_published  (position,published)
#
class Faq < ApplicationRecord
  scope :published, -> {where(published: true).order(position: :asc)}
end
