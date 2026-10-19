# frozen_string_literal: true

ActiveAdmin.register Audio::ChapterAudioFile do
  menu parent: 'Audio'
  includes :chapter,
           :audio_recitation

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

  filter :audio_recitation, as: :searchable_select,
         ajax: { resource: Audio::Recitation }
  filter :resource_content, as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :chapter, as: :searchable_select,
         ajax: { resource: Chapter }
  filter :format
  filter :audio_url
  filter :active

  action_item :debug_segment, only: :show do
    link_to('View in segment tool',
            segment_builder_surah_audio_file_path(resource.audio_recitation_id, chapter_id: resource.chapter_id),
            target: '_blank') if resource.chapter_id
  end

  action_item :validate_segments, only: :show, if: -> { can? :manage, resource } do
    link_to 'Validate segments', '#_',
            data: { controller: 'ajax-modal', css_class: 'modal-xl', url: validate_segments_cms_audio_chapter_audio_file_path(resource) }
  end

  action_item :refresh_meta, only: :show, if: -> { can? :manage, resource } do
    link_to 'Refresh Meta', refresh_meta_cms_audio_chapter_audio_file_path(resource), method: :put
  end

  action_item :bump_content_version, only: :show, if: -> { can? :manage, resource } do
    link_to 'Bump audio version',
            bump_content_version_cms_audio_chapter_audio_file_path(resource),
            method: :put,
            data: { confirm: 'This tells every client to re-download this audio file. Continue?' }
  end

  member_action :validate_segments, method: 'get' do
    authorize! :manage, resource
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
      row :duration do |r|
        total_sec = r.duration
        "#{ActiveAdminViewHelpers.humanize_duration(total_sec)} (#{total_sec} seconds)"
      end
      row :duration_ms
      row :file_name
      row :format
      row :audio_url
      row :segments_count
      row :timing_percentiles
      row :content_version do |file|
        "#{file.published_version} (#{file.content_version_source.presence || 'not set'})"
      end
      row :content_hash
      row :content_etag
      row :content_updated_at
      row :meta_data do
        if resource.meta_data.present?
          div do
            pre do
              code do
                JSON.pretty_generate(resource.meta_data)
              end
            end
          end
        end
      end
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
              td link_to(segment.id, [:cms, segment])
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

  sidebar 'Audio version', only: :show, if: -> { can? :manage, resource } do
    div do
      para "Published as version #{resource.published_version}. It moves on its own when the audio file's fingerprint changes; set it by hand only when the fingerprint can't see the change."
    end

    render partial: 'admin/audio_content_version', locals: { url: override_content_version_cms_audio_chapter_audio_file_path(resource), version: resource.published_version }
  end

  member_action :refresh_meta, method: 'put' do
    Audio::UpdateMetaDataJob.perform_later(resource.audio_recitation, chapter_id: resource.chapter_id, force: true)

    redirect_to [:cms, resource], notice: 'Meta data will be refreshed in a few sec.'
  end

  member_action :bump_content_version, method: 'put' do
    authorize! :manage, resource
    resource.bump_content_version!

    redirect_to [:cms, resource], notice: "Audio version is now #{resource.content_version}."
  end

  member_action :override_content_version, method: 'put' do
    authorize! :manage, resource

    if resource.override_content_version!(params[:content_version])
      redirect_to [:cms, resource], notice: "Audio version is now #{resource.content_version}."
    else
      redirect_to [:cms, resource], alert: 'Version must be a positive number.'
    end
  end

  form do |f|
    f.inputs 'Chapter audio file details' do
      f.input :audio_recitation_id
      f.input :chapter_id
      f.input :duration
      f.input :file_size
      f.input :format
      f.input :mime_type
      f.input :bit_rate
      f.input :file_name

      f.input :meta_data, input_html: { data: { controller: 'json-editor', json: resource.meta_data } }
    end

    f.actions
  end

  permit_params do
    %i[
      audio_recitation_id
      chapter_id
      duration
      file_size
      format
      mime_type
      bit_rate
      file_name
      meta_data
    ]
  end
end
