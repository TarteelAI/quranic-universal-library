# frozen_string_literal: true

ActiveAdmin.register Morphology::GrammarPattern do
  menu parent: 'Morphology'
  actions :index, :show

  filter :arabic
  filter :english

  index do
    id_column
    column :arabic
    column :english
    actions
  end

  show do
    attributes_table do
      row :id
      row :arabic
      row :english
      row :created_at
      row :updated_at
    end
  end
end
