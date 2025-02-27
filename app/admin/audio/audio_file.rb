# frozen_string_literal: true

ActiveAdmin.register AudioFile do
  menu parent: 'Audio'
  actions :all, except: :destroy
  includes :verse

  filter :recitation, as: :searchable_select,
                      ajax: { resource: Recitation }
  filter :verse, as: :searchable_select,
                 ajax: { resource: Verse }
  filter :chapter, as: :searchable_select,
         ajax: { resource: Chapter }
  filter :format

  scope :missing_segments

  action_item :validate_segments, only: :show, if: -> { can? :manage, resource } do
    link_to 'Validate segments', '#_', id: 'validate-segments',
            data: { controller: 'ajax-modal', url: validate_segments_admin_recitation_path(resource.recitation_id, chapter_id: resource.chapter_id) }
  end

  action_item :view_segments, only: :show do
    link_to 'View in segment tool', segment_builder_ayah_audio_file_path(resource.recitation_id, chapter_id: resource.chapter_id, verse: resource.verse_number), target: '_blank', rel: 'noopener'
  end

  index do
    id_column
    column :verse do |resource|
      link_to(resource.verse.verse_key, [:admin, resource.verse])
    end

    column :words_count
    column :segments_count
    column :duration
    column :url
    column :format
    actions
  end

  show do
    attributes_table do
      row :id
      row :verse_key
      row :verse
      row :chapter
      row :url
      row :audio_url
      row :duration
      row :recitation
      row :words_count
      row :segments_count
      row :segments do
        div do
          resource.segments.each do |segment|
            div segment.join(', ')
          end
        end
      end
      row :created_at
      row :updated_at
    end
  end

  permit_params do
    %i[
      verse_id
      url
      audio_url
      duration
      segments
      recitation_id
    ]
  end
end
