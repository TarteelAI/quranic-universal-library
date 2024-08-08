# frozen_string_literal: true

ActiveAdmin.register Audio::Section do
  menu parent: 'Audio'
  permit_params :name

  actions :all, except: :destroy
  filter :name

  searchable_select_options(
    scope: Audio::Section,
    text_attribute: :name,
    filter: lambda do |term, scope|
      scope.ransack(name_cont: term).result
    end
  )

  index do
    id_column
    column :name
    actions
  end
end
