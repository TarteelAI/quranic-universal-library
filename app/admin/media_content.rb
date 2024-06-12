# frozen_string_literal: true

# == Schema Information
#
# Table name: media_contents
#
#  id                  :integer          not null, primary key
#  author_name         :string
#  duration            :string
#  embed_text          :text
#  language_name       :string
#  provider            :string
#  resource_type       :string
#  url                 :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  language_id         :integer
#  resource_content_id :integer
#  resource_id         :integer
#
# Indexes
#
#  index_media_contents_on_language_id                    (language_id)
#  index_media_contents_on_resource_content_id            (resource_content_id)
#  index_media_contents_on_resource_type_and_resource_id  (resource_type,resource_id)
#
ActiveAdmin.register MediaContent do
  menu parent: 'Media', priority: 2
  actions :all, except: :destroy

  show do
    attributes_table do
      row :id
      row :resource
      row :language
      row :url
      row :created_at
      row :updated_at
      row :embed_text do |resource|
        div resource.embed_text.to_s.html_safe
      end
    end
  end

  index do
    id_column
    column :author_name
    column :resource_content
    column :language
    actions
  end

  def scoped_collection
    super.includes :language, :resource_content
  end
end
