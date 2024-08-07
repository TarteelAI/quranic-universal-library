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
ActiveAdmin.register CharType do
  menu parent: 'Settings', priority: 10
  actions :all, except: :destroy
  filter :name

  permit_params do
    %i[name parent_id description]
  end
end
