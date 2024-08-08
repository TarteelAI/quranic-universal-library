# frozen_string_literal: true

ActiveAdmin.register Audio::ChapterAudioFile do
  menu parent: 'Audio'
  actions :all, except: :destroy
  searchable_select_options(
    scope: Audio::ChapterAudioFile,
    text_attribute: :humanize,
    filter: lambda do |term, scope|
      scope.ransack(
        id_eq: term,
        chapter_id: term,
        m: 'or'
      ).result
    end
  )

  permit_params :chapter_id,
                :resource_content_id

  filter :audio_recitation, as: :searchable_select,
         ajax: { resource: Audio::Recitation }
  filter :resource_content, as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :chapter, as: :searchable_select,
         ajax: { resource: Chapter }
  filter :format
  filter :active

  action_item :debug_segment, only: :show do
    link_to 'View in segment tool',
            segment_builder_surah_audio_file_path(resource.chapter_id, recitation_id: resource.audio_recitation_id),
            target: '_blank'
  end

  action_item :validate_segments, only: :show do
    link_to 'Validate segments', '#_',
            data: { controller: 'ajax-modal', url: validate_segments_admin_audio_chapter_audio_file_path(resource) }
  end

  action_item :refresh_meta, only: :show do
    link_to 'Refresh Meta', refresh_meta_admin_audio_chapter_audio_file_path(resource), method: :put
  end

  member_action :validate_segments, method: 'get' do
    audio_recitation = resource.audio_recitation
    @issues = audio_recitation.validate_segments_data(audio_file: resource)
    render partial: 'admin/validate_segments'
  end

  index do
    id_column
    column :chapter
    column :audio_recitation
    column :total_files
    column :bit_rate
    column :file_name
    column :format
    column :active

    actions
  end

  show do
    attributes_table do
      row :id
      row :chapter
      row :resource_content
      row :audio_recitation
      row :file_size do |file|
        "<div title='#{file.file_size} bytes' class=has-tooltip>#{number_to_human_size file.file_size.to_f}</div>".html_safe
      end
      row :bit_rate
      row :duration
      row :duration_ms
      row :file_name
      row :format
      row :audio_url
      row :timing_percentiles
      row :metadata
      row :created_at
      row :updated_at
    end
    active_admin_comments

    panel 'Segments timing' do
      table border: 1 do
        thead do
          th 'ID'
          th 'Verse'
          td 'Duration'
          th 'Start'
          th 'Ends'
          th 'Segment count'
          th 'Segments'
        end

        tbody do
          Audio::Segment.where(audio_file: resource).order('verse_number ASC').each do |segment|
            tr do
              td link_to(segment.id, [:admin, segment])
              td segment.verse_key
              td segment.duration
              td segment.timestamp_from
              td segment.timestamp_to
              td segment.segments.size
              td do
                segment.segments.map { |s| s.join(', ') }.join('<br>').html_safe
              end
            end
          end
        end
      end
    end
  end

  sidebar 'Audio URL', only: :show do
    div(link_to 'View', resource.audio_url)
  end

  member_action :refresh_meta, method: 'put' do
    GenerateSurahAudioFilesJob.perform_later(resource.id, meta: true, chapter: resource.chapter_id)

    redirect_to [:admin, resource], notice: 'Meta data will be refreshed in a few sec.'
  end

  def scoped_collection
    super.includes :chapter, :audio_recitation
  end
end
