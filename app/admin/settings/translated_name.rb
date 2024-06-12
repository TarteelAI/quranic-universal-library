# frozen_string_literal: true

# == Schema Information
#
# Table name: translated_names
#
#  id                :integer          not null, primary key
#  language_name     :string
#  language_priority :integer
#  name              :string
#  resource_type     :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  language_id       :integer
#  resource_id       :integer
#
# Indexes
#
#  index_translated_names_on_language_id                    (language_id)
#  index_translated_names_on_language_priority              (language_priority)
#  index_translated_names_on_resource_type_and_resource_id  (resource_type,resource_id)
#
ActiveAdmin.register TranslatedName do
  menu parent: 'Settings'
  actions :all, except: :new

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
