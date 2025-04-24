# == Schema Information
#
# Table name: resource_tags
#
#  id            :bigint           not null, primary key
#  resource_type :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  resource_id   :integer
#  tag_id        :integer
#
# Indexes
#
#  index_on_resource_tag  (tag_id,resource_id,resource_type)
#
class ResourceTag < QuranApiRecord
  belongs_to :tag
  belongs_to :resource, polymorphic: true

  validates :tag_id, uniqueness: {scope: :resource_id, message: 'Tag already exists for this resource'}
end
