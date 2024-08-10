# frozen_string_literal: true

ActiveAdmin.register ResourceTag do
  menu parent: 'Settings'

  filter :tag, as: :searchable_select,
         ajax: { resource: Tag }

  permit_params do
    %i[tag_id resource_id resource_type]
  end
end
