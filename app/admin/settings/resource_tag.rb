# frozen_string_literal: true

# == Schema Information
#
# Table name: authors
#
#  id         :integer          not null, primary key
#  name       :string
#  url        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
ActiveAdmin.register ResourceTag do
  menu parent: 'Settings'

  filter :tag_id

  permit_params do
    %i[tag_id resource_id resource_type]
  end
end
