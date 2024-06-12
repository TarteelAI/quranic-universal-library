# frozen_string_literal: true

# == Schema Information
#
# Table name: user_projects
#
#  id                  :bigint           not null, primary key
#  admin_notes         :text
#  description         :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  resource_content_id :integer
#  user_id             :integer
#
ActiveAdmin.register UserProject do
  menu false

  permit_params do
    %i[user_id resource_content_id description admin_notes]
  end

  form do |f|
    f.inputs 'User project Details' do
      f.input :user_id

      f.input :description
      f.input :admin_notes

      f.input :resource_content,
              as: :searchable_select,
              ajax: { resource: ResourceContent }
    end
    f.actions
  end
end
