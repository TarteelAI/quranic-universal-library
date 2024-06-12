# frozen_string_literal: true

# == Schema Information
#
# Table name: dictionary_root_definitions
#
#  id              :bigint           not null, primary key
#  definition_type :integer
#  description     :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  word_root_id    :bigint
#
# Indexes
#
#  index_dict_word_definition  (word_root_id)
#
ActiveAdmin.register Dictionary::RootDefinition do
  menu parent: 'Dictionary'

  filter :definition_type, as: :select, collection: proc { [['literal', 1], ['regular', 2]] }
  filter :word_root_id, as: :searchable_select,
                        ajax: { resource: Dictionary::WordRoot }

  permit_params do
    %i[
      definition_type
      description
      word_root_id
    ]
  end

  def scoped_collection
    super.includes :word_root
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
