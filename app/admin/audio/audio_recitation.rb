# frozen_string_literal: true

ActiveAdmin.register Audio::Recitation do
  menu parent: 'Audio'
  actions :all, except: :destroy
  includes :reciter, :qirat_type

  permit_params :name,
                :arabic_name,
                :description,
                :format,
                :home,
                :relative_path,
                :section_id,
                :resource_content_id,
                :approved,
                :priority,
                :recitation_style_id,
                :qirat_type_id,
                :reciter_id,
                :segment_locked

  scope :all
  scope :approved, group: :enabled
  scope :un_approved, group: :enabled

  filter :name
  filter :home
  filter :qirat_type
  filter :relative_path
  filter :recitation_style, as: :searchable_select,
         ajax: { resource: RecitationStyle }
  filter :section, as: :searchable_select,
         ajax: { resource: Audio::Section }
  filter :reciter, as: :searchable_select,
         ajax: { resource: Reciter }
  filter :approved
  filter :segment_locked
  filter :files_count
  filter :segments_count

  searchable_select_options(
    scope: Audio::Recitation,
    text_attribute: :humanize,
    filter: lambda do |term, scope|
      scope.ransack(
        name_cont: term,
        id_eq: term,
        m: 'or'
      ).result
    end
  )

  action_item :generate_audio, only: :show, if: -> { can?(:manage, resource) && resource.missing_audio_files? } do
    link_to 'Generate Audio files', refresh_meta_cms_audio_recitation_path(resource, audio: true), method: :put, data: { confirm: "Are you sure to generate audio files?" }
  end

  action_item :refresh_meta, only: :show, if: -> { can? :manage, resource } do
    link_to 'Refresh Meta', refresh_meta_cms_audio_recitation_path(resource), method: :put, data: {confirm: 'Are you sure to update metadata of audio files?'}
  end

  action_item :split_to_gapped, only: :show, if: -> { can? :manage, resource } do
    link_to 'Generate Gapped recitation', '#_',
            id: 'validate-segments',
            data: { controller: 'ajax-modal', url: split_to_gapped_cms_audio_recitation_path(resource) }
  end

  action_item :validate_segments, only: :show, if: -> { can? :manage, resource } do
    link_to 'Validate segments', '#_', id: 'validate-segments',
            data: {
              controller: 'ajax-modal',
              url: validate_segments_cms_audio_recitation_path(resource)
            }
  end

  action_item :view_segments, only: :show do
    link_to 'View in segment tool', surah_audio_files_path(recitation_id: resource.id), target: '_blank', rel: 'noopener'
  end

  action_item :upload_segments, only: :show, if: -> { can? :manage, resource } do
    link_to 'Upload segments', '#_',
            data: {
              controller: 'ajax-modal',
              url: upload_segments_cms_audio_recitation_path(resource)
            }
  end

  action_item :download_segments, only: :show, if: -> { can? :download, :from_admin } do
    link_to 'Download segments', '#_',
            data: {
              controller: 'ajax-modal',
              url: download_segments_cms_audio_recitation_path(resource)
            }
  end

  action_item :clone_recitation, only: :show, if: -> { can? :manage, resource } do
    link_to 'Clone Recitation', clone_recitation_cms_audio_recitation_path(resource),
            method: :post,
            data: { confirm: "Clone recitation with audio files?" }
  end

  member_action :clone_recitation, method: :post, if: -> { can? :manage, resource } do
    authorize! :manage, resource
    cloned = resource.clone_with_audio_files

    redirect_to [:cms, cloned], notice: "Cloning successfully"
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

  member_action :validate_segments, method: 'get' do
    authorize! :manage, resource

    @issues = resource.validate_segments_data
    render partial: 'admin/validate_segments'
  end

  member_action :split_to_gapped, method: ['get', 'put'] do
    authorize! :manage, resource

    if request.get?
      render partial: 'admin/split_to_gapped'
    else
      surah = params[:surah]
      ayah_from = params[:ayah_from]
      ayah_to = params[:ayah_to]
      ayah_recitation_id = params[:ayah_recitation_id]
      divide_audio = params[:divide_audio] == '1'

      Audio::SplitGaplessRecitationJob.perform_later(
        recitation_id: resource.id,
        surah: surah,
        ayah_from: ayah_from,
        ayah_to: ayah_to,
        divide_audio: divide_audio,
        user_id: current_user.id,
        host: params[:host],
        ayah_recitation_id: ayah_recitation_id,
        create_ayah_recitation: ayah_recitation_id.blank? && params[:create_ayah_recitation] == '1'
      )

      # Restart sidekiq if it's not running
      Utils::System.start_sidekiq

      return redirect_to [:cms, resource], alert: "Ayah by ayah gapped recitation will be generated shortly."
    end
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

      AudioSegment::SurahBySurah.delay.import(
        recitation_id: resource.id,
        file_path: file_path,
        remove_existing: remove_existing
      )

      redirect_to [:cms, resource], notice: 'Segment data will be imported shortly.'
    else
      render partial: 'admin/upload_segments'
    end
  end

  member_action :download_segments, method: ['get', 'put'] do
    authorize! :download, :from_admin

    if request.put?
      format = params[:export_format].presence || 'csv'

      exporter = AudioSegment::SurahBySurah.new(resource)
      begin
        file = exporter.export(format, params[:chapter_id])

        send_file file, filename: "segments-#{resource.id}.#{format}"
      rescue => e
        flash[:error] = e.message
        redirect_to [:cms, resource]
      end
    else
      render partial: 'admin/download_segments'
    end
  end

  index do
    id_column
    column :name
    column :reciter, sortable: :reciter_id
    column :qirat_type, sortable: :qirat_type_id
    column :priority
    column :relative_path
    column :approved
    column :files_count
    column :segments_count
    column :segment_locked

    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :reciter
      row :resource_content do
        resource.get_resource_content
      end
      row :recitation_style
      row :qirat_type
      row :arabic_name
      row :relative_path
      row :format
      row :section
      row :home
      row :description
      row :file_size
      row :approved do
        resource.approved?
      end
      row :priority
      row :qirat_type
      row :segments_count
      row :segment_locked
      row :files_count
      row :created_at
      row :updated_at
    end

    audio_files =  resource
                     .chapter_audio_files
                     .with_segments_counts
                     .includes(:chapter)

    active_admin_comments

    panel "Audio files: (#{resource.files_count} files) " do
      if resource.files_count.to_i < 114
        missing = (1..114).to_a - resource.chapter_audio_files.pluck(:chapter_id)

        div("Audio files missing for surah #{missing.join(', ')}", class: 'flash flash_error') if missing.present?
      end

      table do
        thead do
          td 'ID'
          td 'Surah number'
          td 'URL'
          td 'Duration'
          td 'Ayahs count'
          td 'Semgnets'
        end

        tbody do
          audio_files.order('chapter_id ASC').each do |r|
            tr class: "#{'bg-warning' if r.has_missing_segments?}" do
              td link_to(r.id, [:cms, r])
              td r.chapter_id
              td r.audio_url
              td r.duration
              td r.chapter&.verses_count
              td r.segments_count
            end
          end
        end
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :arabic_name
      f.input :relative_path
      f.input :format
      f.input :home
      f.input :description
      f.input :files_size
      f.input :priority
      f.input :approved
      f.input :section
      f.input :segment_locked

      f.input :resource_content_id,
              as: :searchable_select,
              ajax: { resource: ResourceContent }
      f.input :reciter_id,
              as: :searchable_select,
              ajax: { resource: Reciter }
      f.input :recitation_style_id,
              as: :searchable_select,
              ajax: { resource: RecitationStyle }
      f.input :qirat_type_id,
              as: :searchable_select,
              ajax: { resource: QiratType }
    end

    f.actions
  end

  sidebar 'Change Log', only: :show do
    table do
      thead do
        td :id
        td :des
      end

      tbody do
        resource.audio_change_logs.each do |log|
          tr do
            td link_to(log.id, [:cms, log])
            td log.mini_desc
          end
        end
      end
    end
  end

  sidebar 'Related Recitation', only: :show do
    table do
      thead do
        td :id
        td :name
      end

      tbody do
        resource.related_recitations.each do |recitation|
          tr do
            related = recitation.related_audio_recitation
            td do
              if related
                link_to(related.id, [:cms, related])
              else
                "Missing - #{recitation.id}"
              end
            end
            td related&.name
          end
        end
      end
    end
  end
end
