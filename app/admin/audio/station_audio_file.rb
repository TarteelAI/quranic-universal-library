# frozen_string_literal: true

# == Schema Information
#
# Table name: reciters
#
#  id         :integer          not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
ActiveAdmin.register Radio::StationAudioFile do
  menu parent: 'Audio'

  filter :radio_station, as: :searchable_select,
         ajax: { resource: Radio::Station }
  filter :chapter, as: :searchable_select,
         ajax: { resource: Chapter }

  actions :all, except: :destroy
  includes :radio_station

  permit_params do
    %i[audio_file_id radio_station_id chapter_id]
  end

  index do
    id_column
    column :radio_station
    column :audio_file_id
    column :chapter_id
    actions
  end

  show do
    attributes_table do
      row :id
      row :radio_station
      row :audio_file
      row :chapter
      row :created_at
      row :updated_at
    end

    active_admin_comments
  end

  form do |f|
    f.inputs 'Radio Station Audio File' do
      f.input :audio_file_id
      f.input :radio_station_id
      f.input :chapter_id
    end

    f.actions
  end
end
