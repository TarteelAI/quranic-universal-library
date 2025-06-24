# frozen_string_literal: true

ActiveAdmin.register Slug do
  menu parent: 'Settings'
  actions :all

  filter :locale
  filter :chapter,
         as: :searchable_select,
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

      redirect_to [:cms, chapter], notice: 'Slug created'
    end
  end
end
