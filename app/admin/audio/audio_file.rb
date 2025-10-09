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
  filter :duration
  filter :file_size
  filter :segments_count
  filter :words_count
  filter :has_repetition

  scope :missing_segments

  action_item :validate_segments, only: :show, if: -> { can? :manage, resource } do
    link_to 'Validate segments', '#_', id: 'validate-segments',
            data: { controller: 'ajax-modal', url: validate_segments_cms_recitation_path(resource.recitation_id, chapter_id: resource.chapter_id) }
  end

  action_item :view_segment_tool, only: :show do
    link_to 'View in segment tool', segment_builder_ayah_audio_file_path(resource.recitation_id, chapter_id: resource.chapter_id, verse: resource.verse_number), target: '_blank', rel: 'noopener'
  end

  index do
    id_column
    column :verse do |resource|
      link_to(resource.verse.verse_key, [:cms, resource.verse])
    end

    column :words_count
    column :segments_count
    column :duration
    column :file_size
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
      row :file_size
      row :format
      row :mime_type
      row :bit_rate
      row :recitation
      row :words_count
      row :segments_count
      row :has_repetition
      row :repeated_segments

      row :segments do
        div do
          resource.get_segments.each do |segment|
            div segment.join(', ')
          end
        end
      end
      row :meta_data do
        if resource.meta_data.present?
          pre do
            code do
              JSON.pretty_generate(resource.meta_data)
            end
          end
        end
      end
      row :created_at
      row :updated_at
    end
    active_admin_comments
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
