# frozen_string_literal: true

ActiveAdmin.register Audio::Segment do
  menu parent: 'Audio'
  actions :all, except: :destroy

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

  index do
    id_column
    column :chapter
    column :verse_number
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
      row :verse_key
      row :timestamp_from
      row :timestamp_to
      row :duration
      row :duration_ms
      row :segments do
        div do
          resource.segments.each do |segment|
            div "#{segment.join(', ')} - #{segment[2] - segment[1]}"
          end
        end
      end

      row :relative_segments do
        div do
          resource.relative_segments.each do |segment|
            div "#{segment.join(', ')} - #{segment[2] - segment[1]}"
          end
        end
      end
    end
  end

  def scoped_collection
    super.includes :chapter
  end
end
