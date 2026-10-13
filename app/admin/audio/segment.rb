# frozen_string_literal: true

ActiveAdmin.register Audio::Segment do
  menu parent: 'Audio'
  actions :all, except: :destroy
  includes :chapter,
           :verse

  permit_params :verse_id,
                :verse_number,
                :verse_key,
                :timestamp_from,
                :timestamp_to,
                :percentile,
                :has_repetition,
                :segments,
                :letter_segments,
                :audio_recitation_id,
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

    column :duration_ms do |resource|
      resource.timestamp_to.to_i - resource.timestamp_from.to_i
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

      if resource.letter_segments.present?
        row :letter_segments do
          table_for resource.get_letter_segments, class: 'index_table' do
            column("Word#") { |l| l[0] }
            column("Letter") { |l| span l[1], class: 'qpc-hafs' }
            column("From") { |l| l[2] }
            column("To") { |l| l[3] }
            column("Duration") { |l| "#{l[3].to_i - l[2].to_i} ms" }
          end
        end
      end

      row :segments do
        div do
          resource.get_segments.each do |s|
            div "#{s.join(', ')}  (#{s[2].to_i - s[1].to_i} ms)"
          end
        end
      end
    end
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    f.inputs 'Segment details' do
      f.input :audio_recitation_id
      f.input :audio_file_id
      f.input :chapter_id
      f.input :verse_id
      f.input :verse_number
      f.input :verse_key
      f.input :timestamp_from, hint: 'ms'
      f.input :timestamp_to, hint: 'ms'
      f.input :percentile
      f.input :has_repetition
    end

    f.inputs 'Segments' do
      # jsonb columns must be submitted as JSON, not Ruby array#to_s. The
      # json-editor controller keeps the hidden input as valid JSON and the
      # model's setter parses it; entries with 0/0 timing are dropped on save.
      f.input :segments,
              as: :text,
              hint: 'Array of [word_number, from_ms, to_ms] entries. Placeholder entries with 0 start and 0 end are removed on save.',
              input_html: { data: { controller: 'json-editor', json: resource.get_segments } }

      f.input :letter_segments,
              as: :text,
              hint: 'Array of [word_number, letter, from_ms, to_ms] entries.',
              input_html: { data: { controller: 'json-editor', json: resource.get_letter_segments } }
    end

    f.actions
  end
end
