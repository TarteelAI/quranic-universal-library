# frozen_string_literal: true

# == Schema Information
#
# Table name: recitations
#
#  id                  :integer          not null, primary key
#  reciter_name        :string
#  style               :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  qirat_type_id       :integer
#  recitation_style_id :integer
#  reciter_id          :integer
#  resource_content_id :integer
#
# Indexes
#
#  index_recitations_on_qirat_type_id        (qirat_type_id)
#  index_recitations_on_recitation_style_id  (recitation_style_id)
#  index_recitations_on_reciter_id           (reciter_id)
#  index_recitations_on_resource_content_id  (resource_content_id)
#
ActiveAdmin.register Recitation do
  menu parent: 'Audio', priority: 1, label: 'Gapped Recitations(ayah by ayah)'
  actions :all, except: :destroy
  includes :reciter, :resource_content

  filter :recitation_style, as: :searchable_select,
         ajax: { resource: RecitationStyle }
  filter :reciter, as: :searchable_select,
         ajax: { resource: Reciter }

  searchable_select_options(scope: Recitation,
                            text_attribute: :reciter_name,
                            filter: lambda do |term, scope|
                              scope.ransack(
                                id_eq: term,
                                m: 'or'
                              ).result
                            end)

  action_item :validate_segments, only: :show, if: -> { can? :manage, resource } do
    link_to 'Validate segments', '#_', id: 'validate-segments',
            data: { controller: 'ajax-modal', url: validate_segments_cms_recitation_path(resource) }
  end

  action_item :generate_audio, only: :show, if: -> { can?(:manage, resource) && resource.missing_audio_files? } do
    link_to 'Generate Audio files', refresh_meta_cms_recitation_path(resource, audio: true), method: :put, data: { confirm: "Are you sure to generate audio files?" }
  end

  action_item :refresh_meta, only: :show, if: -> { can? :manage, resource } do
    link_to 'Refresh Meta', refresh_meta_cms_recitation_path(resource), method: :put, data: { confirm: "Are you sure to update metadata of audio files?" }
  end

  action_item :view_segments, only: :show do
    link_to 'View in segment tool', ayah_audio_files_path(id: resource.id), target: '_blank', rel: 'noopener'
  end

  action_item :download_segments, only: :show, if: -> { can? :download, :from_admin } do
    link_to 'Download segments', '#_',
            data: {
              controller: 'ajax-modal',
              url: download_segments_cms_recitation_path(resource)
            }
  end

  action_item :upload_segments, only: :show, if: -> { can? :manage, resource } do
    link_to 'Upload segments', '#_',
            data: {
              controller: 'ajax-modal',
              url: upload_segments_cms_recitation_path(resource)
            }
  end

  member_action :refresh_meta, method: 'put', if: -> { can? :manage, resource } do
    authorize! :manage, resource
    notice = if params[:audio]
               Audio::GenerateAudioFilesJob.perform_later(resource)
               'Audio files will be generated in a few sec.'
             else
               Audio::UpdateMetaDataJob.perform_later(resource)
               'Meta data will be refreshed in a few sec.'
             end

    # Restart sidekiq if it's not running
    Utils::System.start_sidekiq
    redirect_to [:cms, resource], notice: notice
  end

  member_action :upload_segments, method: ['get', 'put'] do
    authorize! :manage, resource

    if request.put?
      if resource.segment_locked?
        return redirect_to [:cms, resource], alert: "Segments data is locked, please contact admins."
      end

      file = params[:file].path
      ext = File.extname(file)
      file_path = "#{Rails.root}/public/segments_data/#{resource.id}#{ext}"
      remove_existing = params[:remove_existing] == '1'

      FileUtils.mkdir_p("#{Rails.root}/public/segments_data")
      FileUtils.mv(file, file_path)

      AudioSegment::AyahByAyah.delay.import(
        recitation_id: resource.id,
        file_path: file_path,
        remove_existing: remove_existing
      )

      redirect_to [:cms, resource], notice: 'Segment data will be imported shortly.'
    else
      render partial: 'admin/upload_segments'
    end
  end

  member_action :validate_segments, method: 'get' do
    authorize! :manage, resource

    @issues = resource.validate_segments_data(chapter_id: params[:chapter_id])
    render partial: 'admin/validate_segments'
  end

  permit_params do
    %i[
      name
      relative_path
      reciter_id
      recitation_style_id
      resource_content_id
      qirat_type_id
      style
      segment_locked
      reciter_name
    ]
  end

  index do
    id_column
    column :name
    column :relative_path
    column :approved?, sortable: 'resource_contents.approved'
    column :reciter, sortable: 'reciters.name'
    column :recitation_style
    column :qirat_type

    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :relative_path
      row :reciter
      row :qirat_type
      row :reciter_name
      row :recitation_style do |r|
        link_to r.recitation_style.name, [:cms, r.recitation_style] if r.recitation_style
      end

      row :resource_content do |r|
        if r.resource_content
          link_to "#{r.resource_content.id}-#{r.resource_content.name}", [:cms, r.resource_content]
        end
      end

      row :approved do
        resource.approved?
      end
      row :segment_locked
      row :created_at
      row :updated_at
    end
    active_admin_comments
  end

  form do |f|
    f.inputs 'Recitation Details' do
      f.input :name
      f.input :relative_path
      f.input :reciter
      f.input :reciter_name

      f.input :resource_content,
              as: :searchable_select,
              ajax: { resource: ResourceContent }

      f.input :recitation_style_id,
              as: :searchable_select,
              ajax: { resource: RecitationStyle }
      f.input :qirat_type_id,
              as: :searchable_select,
              ajax: { resource: QiratType }
      f.input :segment_locked
    end

    f.actions
  end

  sidebar 'Audio files', only: :show do
    div do
      link_to 'View audio files', "/cms/audio_files?utf8=✓&q%5Brecitation_id_eq%5D=#{resource.id}"
    end
  end

  member_action :download_segments, method: ['get', 'put'] do
    authorize! :download, :from_admin

    if request.put?
      format = params[:export_format].presence || 'csv'
      file = resource.export_segments(format, params[:chapter_id])

      send_file file, filename: "segments-#{resource.id}.#{format}"
    else
      render partial: 'admin/download_gapped_segments'
    end
  end

  # Export multiple recitation segments to sqlite db
  collection_action :export_sqlite_db, method: 'put' do
    authorize! :download, :from_admin

    file_name = params[:file_name].presence || 'reciter-audio-timing.sqlite'
    table_name = params[:table_name].presence || 'ayah_timing'
    recitations_ids = params[:reciter_ids].split(',').compact_blank
    export_gapless = params[:export_gapless] == '1'

    Audio::ExportAudioSegmentsJob.perform_later(
      file_name: file_name,
      table_name: table_name,
      user_id: current_user.id,
      recitations_ids: recitations_ids,
      gapless: export_gapless
    )
    # Restart sidekiq if it's not running
    Utils::System.start_sidekiq

    redirect_back(fallback_location: '/cms', notice: 'Recitation segments db will be shared via email.')
  end
end
