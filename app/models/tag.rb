# == Schema Information
#
# Table name: tags
#
#  id          :bigint           not null, primary key
#  description :string
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_tags_on_name  (name)
#
class Tag < QuranApiRecord
  has_many :resource_tags

  has_many :resources, through: :resource_tags, source: :resource,
           source_type: 'ResourceContent'
end
