# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_related_recitations
#
#  id                          :bigint           not null, primary key
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  audio_recitation_id         :integer
#  related_audio_recitation_id :integer
#
# Indexes
#
#  index_audio_related_recitation  (audio_recitation_id,related_audio_recitation_id)
#
ActiveAdmin.register Audio::RelatedRecitation do
  menu parent: 'Audio'
  actions :all, except: :destroy
  includes :audio_recitation,
           :related_audio_recitation

  filter :audio_recitation, as: :searchable_select,
                            ajax: { resource: Audio::Recitation }

  filter :related_audio_recitation, as: :searchable_select,
                                    ajax: { resource: Audio::Recitation }

  index do
    id_column
    column :audio_recitation
    column :related_audio_recitation

    actions
  end

end
