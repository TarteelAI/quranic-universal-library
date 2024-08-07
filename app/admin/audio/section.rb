# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_sections
#
#  id         :bigint           not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
ActiveAdmin.register Audio::Section do
  menu parent: 'Audio'
  permit_params :name

  actions :all, except: :destroy
  filter :name

  searchable_select_options(scope: Audio::Section,
                            text_attribute: :name,
                            filter: lambda do |term, scope|
                              scope.ransack(name_cont: term).result
                            end)
  index do
    id_column
    column :name
    actions
  end
end
