# frozen_string_literal: true

ActiveAdmin.register Morphology::WordVerbForm do
  menu parent: 'Morphology'
  actions :index, :show
  includes :word

  filter :word_id, as: :numeric
  filter :name
  filter :value

  index do
    id_column
    column :word do |resource|
      resource.word && link_to(resource.word.location, [:cms, resource.word])
    end
    column :name
    column :value
    actions
  end

  show do
    attributes_table do
      row :id
      row :word do |resource|
        resource.word && link_to(resource.word.location, [:cms, resource.word])
      end
      row :name
      row :value
      row :created_at
      row :updated_at
    end
  end
end
