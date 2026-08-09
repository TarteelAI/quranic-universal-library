# frozen_string_literal: true

ActiveAdmin.register AyahTimestampVote do
  menu parent: 'Audio', label: 'Timestamp votes', priority: 20

  actions :index, :show

  filter :vote, as: :select, collection: AyahTimestampVote::VOTES
  filter :verse_key
  filter :audio_recitation_id
  filter :audio_segment_id
  filter :user_id
  filter :created_at

  index do
    selectable_column
    id_column
    column :verse_key
    column :vote do |vote|
      status_tag vote.vote
    end
    column :audio_recitation_id
    column :audio_segment_id
    column :user
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :verse_key
      row :chapter_id
      row :verse_number
      row :vote
      row :audio_recitation_id
      row :audio_segment_id
      row :user
      row :created_at
      row :updated_at
    end
  end
end
