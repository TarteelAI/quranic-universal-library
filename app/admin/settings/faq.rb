# frozen_string_literal: true

# == Schema Information
#
# Table name: char_types
#
#  id          :integer          not null, primary key
#  description :text
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  parent_id   :integer
#
# Indexes
#
#  index_char_types_on_parent_id  (parent_id)
#
ActiveAdmin.register Faq do
  menu parent: 'Settings'

  filter :published
  filter :question
  filter :answer
  filter :created_at

  show do
    attributes_table do
      row :id
      row :published
      row :question
      row :answer
      row :created_at
      row :updated_at
    end
    active_admin_comments
  end

  form do |f|
    f.inputs do
      f.input :published
      f.input :position
      f.input :question
      f.input :answer, input_html: {data: {controller: 'tinymce'}}
    end

    f.actions
  end

  permit_params do
    %i[
    published
    position
    question
    answer
   ]
  end
end