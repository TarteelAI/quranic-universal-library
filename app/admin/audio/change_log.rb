# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_change_logs
#
#  id                  :bigint           not null, primary key
#  date                :datetime
#  mini_desc           :text
#  rss_desc            :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  audio_recitation_id :integer
#
ActiveAdmin.register Audio::ChangeLog do
  menu parent: 'Audio'
  actions :all, except: :destroy

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

  def scoped_collection
    super.includes :audio_recitation
  end
end
