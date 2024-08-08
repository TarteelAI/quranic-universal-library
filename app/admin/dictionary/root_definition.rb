# frozen_string_literal: true

ActiveAdmin.register Dictionary::RootDefinition do
  menu parent: 'Dictionary'
  includes :word_root
  filter :definition_type, as: :select, collection: proc { [['literal', 1], ['regular', 2]] }
  filter :word_root, as: :searchable_select,
                        ajax: { resource: Dictionary::WordRoot }

  permit_params do
    %i[
      definition_type
      description
      word_root_id
    ]
  end

  form do |f|
    f.inputs 'Root word defination detail' do
      f.input :word_root,
              as: :searchable_select,
              ajax: { resource: Dictionary::WordRoot }

      f.input :definition_type
      f.input :description
    end

    f.actions
  end
end
