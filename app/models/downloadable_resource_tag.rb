# == Schema Information
#
# Table name: downloadable_resource_tags
#
#  id          :bigint           not null, primary key
#  description :text
#  glossary    :string
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_downloadable_resource_tags_on_name  (name)
#
class DownloadableResourceTag < ApplicationRecord
  has_many :downloadable_resource_taggings
  has_many :downloadable_resources, through: :downloadable_resource_taggings

  def to_s
    name
  end
end
