# frozen_string_literal: true

ActiveAdmin.register TranslatedName do
  menu parent: 'Settings'
  actions :all, except: :new

  filter :language, as: :searchable_select,
         ajax: { resource: Language }
  filter :resource_id
  filter :resource_type
  filter :name

  permit_params do
    %i[resource_type resource_id name language_id]
  end

  form do |f|
    f.inputs do
      f.input :resource_id, as: :hidden
      f.input :resource_type, as: :hidden
      f.input :name, required: true
      f.input :language_id,
              required: true,
              as: :searchable_select,
              ajax: { resource: Language }
    end

    f.actions
  end
end
