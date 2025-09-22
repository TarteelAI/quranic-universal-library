# == Schema Information
#
# Table name: root_details
#
#  id                  :bigint           not null, primary key
#  meta_data           :jsonb            not null
#  text                :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  language_id         :integer
#  resource_content_id :integer
#  root_id             :integer
#  token_id            :integer
#
# Indexes
#
#  index_root_details_on_language_id          (language_id)
#  index_root_details_on_resource_content_id  (resource_content_id)
#  index_root_details_on_root_id              (root_id)
#  index_root_details_on_token_id             (token_id)
#
class RootDetail < QuranApiRecord
  has_paper_trail

  belongs_to :resource_content
  belongs_to :language
  belongs_to :root, optional: true

  validates :token_id, presence: true
end
