# == Schema Information
#
# Table name: proof_read_comments
#
#  id            :bigint           not null, primary key
#  resource_type :string           not null
#  text          :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  resource_id   :bigint           not null
#  user_id       :bigint
#
# Indexes
#
#  index_proof_read_comments_on_resource_type_and_resource_id  (resource_type,resource_id)
#  index_proof_read_comments_on_user_id                        (user_id)
#

class ProofReadComment < ApplicationRecord
  belongs_to :user
  belongs_to :resource, polymorphic: true
end
