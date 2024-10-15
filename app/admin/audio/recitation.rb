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
  menu parent: 'Audio', priority: 1
  actions :all, except: :destroy
  includes :reciter

  filter :recitation_style, as: :searchable_select,
         ajax: { resource: RecitationStyle }
  filter :reciter, as: :searchable_select,
         ajax: { resource: Reciter }
  filter :approved

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
            data: { controller: 'ajax-modal', url: validate_segments_admin_recitation_path(resource) }
  end

  action_item :view_segments, only: :show do
    link_to 'View in segment tool', ayah_audio_files_path(id: resource.id), target: '_blank', rel: 'noopener'
  end

  member_action :validate_segments, method: 'get' do
    authorize! :manage, resource

    @issues = resource.validate_segments_data(chapter_id: params[:chapter_id])
    render partial: 'admin/validate_segments'
  end

  permit_params do
    %i[
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
    column :reciter
    column :recitation_style
    column :qirat_type

    actions
  end

  show do
    attributes_table do
      row :id
      row :reciter
      row :qirat_type
      row :reciter_name
      row :recitation_style do |r|
        link_to r.recitation_style.name, [:admin, r.recitation_style] if r.recitation_style
      end

      row :resource_content do |r|
        if r.resource_content
          link_to "#{r.resource_content.id}-#{r.resource_content.name}", [:admin, r.resource_content]
        end
      end

      row :approved, &:approved?
      row :segment_locked
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs 'Recitation Details' do
      f.input :reciter
      f.input :resource_content,
              as: :searchable_select,
              ajax: { resource: ResourceContent }

      f.input :reciter_name

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
      link_to 'View audio files', "/admin/audio_files?utf8=✓&q%5Brecitation_id_eq%5D=#{resource.id}"
    end
  end

  collection_action :export_sqlite_db, method: 'put' do
    authorize! :download, :from_admin

    file_name = params[:file_name].presence || 'reciter-audio-timing.sqlite'
    table_name = params[:file_name].presence || 'ayah_timing'
    recitations_ids = params[:reciter_ids].split(',').compact_blank

    Export::AyahRecitationSegmentsJob.perform_later(
      file_name: file_name,
      table_name: table_name,
      user_id: current_user.id,
      recitations_ids: recitations_ids
    )
    # Restart sidekiq if it's not running
    Utils::System.start_sidekiq

    redirect_back(fallback_location: '/admin', notice: 'Recitation segments db will be shared via email.')
  end
end
