# == Schema Information
#
# Table name: root_details
#
#  id                  :bigint           not null, primary key
#  language_name       :string
#  meta_data           :jsonb            not null
#  root_detail         :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  language_id         :integer
#  resource_content_id :integer
#  root_id             :integer          not null
#
# Indexes
#
#  index_root_details_on_language_id          (language_id)
#  index_root_details_on_language_name        (language_name)
#  index_root_details_on_resource_content_id  (resource_content_id)
#  index_root_details_on_root_id              (root_id)
#
class RootDetail < QuranApiRecord
  has_paper_trail

  belongs_to :resource_content
  belongs_to :language
  belongs_to :root
  validates :root_id, presence: true
end
