# frozen_string_literal: true

ActiveAdmin.register Audio::ChangeLog do
  menu parent: 'Audio'
  actions :all, except: :destroy
  includes :audio_recitation
  filter :date
  filter :audio_recitation, as: :searchable_select,
                            ajax: { resource: Audio::Recitation }

  index do
    id_column
    column :audio_recitation
    column :date
    column :mini_desc

    actions
  end

  permit_params :audio_recitation_id, :date, :mini_desc
end
