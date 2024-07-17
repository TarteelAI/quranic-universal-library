# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_recitations
#
#  id                  :bigint           not null, primary key
#  approved            :boolean
#  arabic_name         :string
#  description         :text
#  files_count         :integer
#  files_size          :integer
#  format              :string
#  home                :integer
#  name                :string
#  priority            :integer
#  relative_path       :string
#  segments_count      :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  qirat_type_id       :integer
#  recitation_style_id :integer
#  reciter_id          :integer
#  resource_content_id :integer
#  section_id          :integer
#
# Indexes
#
#  index_audio_recitations_on_approved             (approved)
#  index_audio_recitations_on_name                 (name)
#  index_audio_recitations_on_priority             (priority)
#  index_audio_recitations_on_recitation_style_id  (recitation_style_id)
#  index_audio_recitations_on_reciter_id           (reciter_id)
#  index_audio_recitations_on_relative_path        (relative_path)
#  index_audio_recitations_on_resource_content_id  (resource_content_id)
#  index_audio_recitations_on_section_id           (section_id)
#
ActiveAdmin.register Audio::Recitation do
  menu parent: 'Audio'
  actions :all, except: :destroy

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
  filter :reciter_id, as: :searchable_select,
         ajax: { resource: Reciter }
  filter :segment_locked

  searchable_select_options(scope: Audio::Recitation,
                            text_attribute: :humanize,
                            filter: lambda do |term, scope|
                              scope.ransack(
                                name_cont: term,
                                id_eq: term,
                                m: 'or'
                              ).result
                            end)

  action_item :refresh_meta, only: :show do
    link_to 'Refresh Meta', refresh_meta_admin_audio_recitation_path(resource), method: :put
  end

  action_item :split_to_gapped, only: :show do
    link_to 'Generate Gapped recitation', '#_', id: 'validate-segments',
            data: { controller: 'ajax-modal', url: split_to_gapped_admin_audio_recitation_path(resource) }
  end

  action_item :validate_segments, only: :show do
    link_to 'Validate segments', '#_', id: 'validate-segments',
            data: { controller: 'ajax-modal', url: validate_segments_admin_audio_recitation_path(resource) }
  end

  action_item :view_segments, only: :show do
    link_to 'View in segment tool', surah_audio_files_path(recitation_id: resource.id), target: '_blank', rel: 'noopener'
  end

  action_item :upload_segments, only: :show do
    link_to 'Upload segments', '#_',
            data: { controller: 'ajax-modal', url: upload_segments_admin_audio_recitation_path(resource) }
  end

  action_item :download_segments, only: :show do
    link_to 'Download segments', '#_',
            data: { controller: 'ajax-modal', url: download_segments_admin_audio_recitation_path(resource) }
  end

  member_action :refresh_meta, method: 'put' do
    GenerateSurahAudioFilesJob.perform_later(resource.id, meta: true)

    redirect_to [:admin, resource], notice: 'Meta data will be refreshed in a few sec.'
  end

  member_action :validate_segments, method: 'get' do
    @issues = resource.validate_segments_data
    render partial: 'admin/validate_segments'
  end

  member_action :split_to_gapped, method: ['get', 'put'] do
    if request.get?
      render partial: 'admin/split_to_gapped'
    else
      Export::SplitGapelessRecitationJob.perform_later(resource.id, params[:host].to_s.strip, current_user.id)
      return redirect_to [:admin, resource], alert: "Ayah by ayah gapped recitation will be generated shortly."
    end
  end

  member_action :upload_segments, method: ['get', 'put'] do
    if request.put?
      if resource.segment_locked?
        return redirect_to [:admin, resource], alert: "Segments data is locked, please contact admins."
      end

      file = params[:file].path
      ext = File.extname(file)
      file_path = "#{Rails.root}/public/segments_data/#{resource.id}#{ext}"

      FileUtils.mkdir_p("#{Rails.root}/public/segments_data")
      FileUtils.mv(file, file_path)

      remove_existing = params[:remove_existing] == '1'
      resource.import_segments_db(file_path, resource.id, remove_existing: remove_existing, async: true)

      redirect_to [:admin, resource], notice: 'Segment data will be imported shortly.'
    else
      render partial: 'admin/upload_segments'
    end
  end

  member_action :download_segments, method: ['get', 'put'] do
    if request.put?
      format = params[:export_format].presence || 'csv'
      file = resource.export_segments(format, params[:chapter_id])

      send_file file, filename: "segments-#{resource.id}.#{format}"
    else
      render partial: 'admin/download_segments'
    end
  end

  def scoped_collection
    super.includes :reciter, :qirat_type
  end

  index do
    id_column
    column :name
    column :reciter, sortable: :reciter_id
    column :qirat_type, sortable: :qirat_type_id
    column :priority
    column :relative_path
    column :home
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
      row :approved
      row :priority
      row :qirat_type
      row :segments_count
      row :segment_locked
      row :files_count
      row :created_at
      row :updated_at
    end

    panel "Surah recitations: (#{resource.files_count} files) " do
      if resource.files_count.to_i < 114
        missing = (1..114).to_a - resource.chapter_audio_files.pluck(:chapter_id)

        div("Audio files missing for surah #{missing.join(', ')}", class: 'flash flash_error') if missing.present?
      end

      table do
        thead do
          td 'ID'
          td 'Surah number'
          td 'URL'
          td 'Semgnets'
        end

        tbody do
          resource.chapter_audio_files.with_segments_counts.order('chapter_id ASC').each do |r|
            tr do
              td link_to(r.id, [:admin, r])
              td r.chapter_id
              td r.audio_url
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
            td link_to(log.id, [:admin, log])
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
                link_to(related.id, [:admin, related])
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
