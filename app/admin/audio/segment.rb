# frozen_string_literal: true

ActiveAdmin.register Audio::Segment do
  menu parent: 'Audio'
  actions :all, except: :destroy
  includes :chapter,
           :verse

  permit_params :verse_id,
                :duration,
                :end_timestamp,
                :percentile,
                :segments,
                :start_timestamp,
                :verse_number,
                :audio_file_id,
                :chapter_id

  filter :audio_recitation_id, as: :searchable_select,
                               ajax: { resource: Audio::Recitation }
  filter :verse_id, as: :searchable_select,
                    ajax: { resource: Verse }

  filter :audio_file_id, as: :searchable_select,
                         ajax: { resource: Audio::ChapterAudioFile }

  filter :chapter_id, as: :searchable_select,
                      ajax: { resource: Chapter }
  filter :has_repetition

  index do
    id_column
    column :chapter, sortable: :chapter_id
    column :verse_number
    column :verse_key, sortable: :verse_id
    column :timestamp_from
    column :timestamp_to

    column :duration
    column :diff do |resource|
      resource.timestamp_to - resource.timestamp_from
    end

    actions
  end

  show do
    attributes_table do
      row :id
      row :chapter_audio_file
      row :audio_recitation
      row :chapter
      row :verse
      row :verse_key
      row :timestamp_from
      row :timestamp_to
      row :duration
      row :duration_ms
      row :has_repetition
      row :repeated_segments

      row :segments do
        div do
          resource.get_segments.each do |s|
            div "#{s.join(', ')}  (#{s[2].to_i - s[1].to_i} ms)"
          end
        end
      end
    end
  end
end
