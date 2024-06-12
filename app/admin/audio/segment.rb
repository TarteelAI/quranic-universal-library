# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_segments
#
#  id                       :bigint           not null, primary key
#  duration                 :integer
#  duration_ms              :integer
#  percentile               :float
#  relative_segments        :jsonb
#  relative_silent_duration :integer
#  segments                 :jsonb
#  silent_duration          :integer
#  timestamp_from           :integer
#  timestamp_median         :integer
#  timestamp_to             :integer
#  verse_key                :string
#  verse_number             :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  audio_file_id            :bigint
#  audio_recitation_id      :bigint
#  chapter_id               :bigint
#  verse_id                 :bigint
#
# Indexes
#
#  index_audio_segments_on_audio_file_id                   (audio_file_id)
#  index_audio_segments_on_audio_file_id_and_verse_number  (audio_file_id,verse_number) UNIQUE
#  index_audio_segments_on_audio_recitation_id             (audio_recitation_id)
#  index_audio_segments_on_chapter_id                      (chapter_id)
#  index_audio_segments_on_verse_id                        (verse_id)
#  index_audio_segments_on_verse_number                    (verse_number)
#  index_on_audio_segments_median_time                     (audio_recitation_id,chapter_id,verse_id,timestamp_median)
#
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
