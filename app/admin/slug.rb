# frozen_string_literal: true

# == Schema Information
#
# Table name: slugs
#
#  id                :bigint           not null, primary key
#  is_default        :boolean          default(FALSE)
#  language_priority :integer
#  locale            :string
#  name              :string
#  slug              :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  chapter_id        :bigint
#  language_id       :integer
#
# Indexes
#
#  index_slugs_on_chapter_id           (chapter_id)
#  index_slugs_on_chapter_id_and_slug  (chapter_id,slug)
#  index_slugs_on_is_default           (is_default)
#  index_slugs_on_language_id          (language_id)
#  index_slugs_on_language_priority    (language_priority)
#
ActiveAdmin.register Slug do
  menu parent: 'Content'
  actions :all

  filter :locale
  filter :chapter_id, as: :searchable_select,
                      ajax: { resource: Chapter }

  show do
    attributes_table do
      row :id
      row :chapter
      row :slug
      row :locale
      row :created_at
      row :updated_at
    end
  end

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # permit_params :list, :of, :attributes, :on, :model
  #
  # or
  #
  permit_params do
    %i[locale chapter_id slug]
  end

  controller do
    def create
      p = permitted_params[:slug]
      chapter = Chapter.find(p[:chapter_id])
      chapter.add_slug(p[:slug], p[:locale])

      redirect_to [:admin, chapter], notice: 'Slug created'
    end
  end
end
