# == Schema Information
#
# Table name: downloadable_resource_tags
#
#  id              :bigint           not null, primary key
#  color_class     :string
#  description     :text
#  glossary_term   :string
#  name            :string
#  resources_count :integer
#  slug            :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_downloadable_resource_tags_on_name  (name)
#
class DownloadableResourceTag < ApplicationRecord
  has_many :downloadable_resource_taggings
  has_many :downloadable_resources, through: :downloadable_resource_taggings
  before_save :generate_slug

  def to_s
    name
  end

  protected
  def generate_slug
    if slug.blank?
      self.slug = name.parameterize
    end
  end
end
