# frozen_string_literal: true

ActiveAdmin.register ResourceContent do
  before_action do
    ActiveStorage::Current.url_options = {
      protocol: request.protocol,
      host: request.host,
      port: request.port
    }
  end

  searchable_select_options(
    scope: ResourceContent,
    text_attribute: :humanize,
    filter: lambda do |term, scope|
      scope.ransack(
        name_cont: term,
        language_name_cont: term,
        resource_id_eq: term,
        m: 'or'
      ).result
    end
  )

  menu parent: 'Content', priority: 1
  actions :all, except: :destroy
  includes :language

  scope :with_footnotes
  scope :from_quranenc
  scope :approved

  scope :without_downloadable_resources, group: 'downloadable'
  scope :with_downloadable_resources, group: 'downloadable'

  filter :name
  filter :approved
  filter :quran_enc_key, as: :string
  filter :slug, as: :string
  filter :data_source, as: :searchable_select,
         ajax: { resource: DataSource }
  filter :permission_to_host, as: :select, collection: lambda {
    ResourcePermission.permission_to_hosts.keys
  }
  filter :permission_to_share, as: :select, collection: lambda {
    ResourcePermission.permission_to_shares.keys
  }
  filter :cardinality_type, as: :select, collection: lambda {
    ResourceContent.collection_for_cardinality_type
  }
  filter :resource_type, as: :select, collection: lambda {
    ResourceContent.collection_for_resource_type
  }
  filter :sub_type, as: :select, collection: lambda {
    ResourceContent.collection_for_sub_type
  }
  filter :language, as: :searchable_select,
         ajax: { resource: Language }
  filter :created_at
  filter :updated_at

  ActiveAdminViewHelpers.render_translated_name_sidebar(self)

  action_item :approve, only: :show, if: -> { can? :manage, ResourceContent } do
    link_to approve_admin_resource_content_path(resource), method: :put, data: { confirm: 'Are you sure?' } do
      resource.approved? ? 'Un Approve!' : 'Approve!'
    end
  end

  action_item :import_draft, only: :show, if: -> { can? :manage, Draft::Translation } do
    if resource.sourced_from_quranenc?
      type = resource.tafsir? ? 'tafsir' : 'translation'
      link_to "Import Draft #{type}", import_draft_admin_resource_content_path(resource), method: :put,
              data: { confirm: "Are you sure to import #{type} for this resource from QuranEnc?" }
    end
  end

  member_action :upload_file, method: 'post' do
    authorize! :upload_file, resource

    permitted = params.require(:resource_content).permit source_files: []

    permitted['source_files'].each do |attachment|
      resource.source_files.attach(attachment)
    end

    redirect_to [:admin, resource], notice: 'File saved successfully'
  end

  member_action :approve, method: 'put' do
    authorize! :update, resource
    resource.toggle_approve!

    redirect_to [:admin, resource], notice: resource.approved? ? 'Approved successfully' : 'Un approved successfully'
  end

  member_action :validate_draft, method: 'get' do
    @resource = resource
    @issues = resource.check_for_missing_draft_tafsirs
    render partial: 'admin/validate_draft_tafsir'
  end

  member_action :import_draft, method: 'put' do
    authorize! :manage, resource

    if !current_user.super_admin?
      return redirect_back fallback_location: "/admin/draft_tafsirs?q%5Bresource_content_id_eq%5D=#{resource.id}", alert: 'Sorry, you can not perform this action'
    end
    # Restart sidekiq if it's not running
    Utils::System.start_sidekiq

    if params[:approved]
      QuranEnc::ApproveDraftTranslationJob.perform_later(resource.id)
      flash[:notice] = "#{resource.name} will be imported shortly!"
    elsif params[:remove_draft]
      QuranEnc::ApproveDraftTranslationJob.perform_later(resource.id, remove_draft: true)
      flash[:notice] = "#{resource.name} will be removed shortly!"
    else
      QuranEnc::ImportDraftTranslationJob.perform_later(resource.id)
      flash[:notice] = "#{resource.name} will be synced shortly!"
    end

    url = if resource.tafsir?
            "/admin/draft_tafsirs?q%5Bresource_content_id_eq%5D=#{resource.id}"
          elsif resource.translation?
            "/admin/draft_translations?q%5Bresource_content_id_eq%5D=#{resource.id}"
          else
            [:admin, resource]
          end

    redirect_to url
  end

  member_action :export, method: 'put' do
    authorize! :export, resource

    permitted = params
                  .require(:resource_content)
                  .permit(
                    :export_file_name,
                    :include_footnote,
                    :export_format
                  )
                  .to_h
    export_type = permitted[:export_format].to_s.strip
    resource.touch # update version

    if export_type == 'sqlite'
      ExportTranslationJob.perform_later(resource.id, permitted[:export_file_name], permitted[:include_footnote] == 'true', current_user.id)
    elsif export_type == 'raw_files'
      Export::RawTrafsirJob.perform_later(resource.id, permitted[:export_file_name], current_user.id)
    elsif ['json_nested_array', 'json_text_chunks'].include?(export_type)
      Export::TranslationJob.perform_later(resource.id, current_user.id, export_type == 'json_nested_array')
    elsif export_type == 'tafsir_json'
      if resource.tafsir?
        Export::TafsirJob.perform_later(resource.id, permitted[:export_file_name].to_s.strip, current_user.id)
      end
    else
      flash[:error] = "Invalid export type"
      return redirect_to [:admin, resource]
    end

    redirect_to [:admin, resource], notice: "#{resource.name} will be exported and sent to you via email. You can also download the export from this page after few minutes."
  end

  index do
    id_column

    column :name
    column :slug
    column :approved
    column :cardinality_type
    column :sub_type
    column :records_count

    column :language do |resource|
      link_to resource.language_name, admin_language_path(resource.language_id) if resource.language_id
    end
    column :created_at
    column :updated_at

    actions
  end

  show do
    permission = resource.resource_permission

    if permission&.copyright_notice.present?
      div class: 'alert alert-danger fs-lg' do
        permission.copyright_notice.html_safe
      end
    end

    attributes_table do
      row :id
      row :name
      row :approved
      row :language
      row :priority
      row :cardinality_type
      row :sub_type
      row :resource_type
      row :records_count
      row :slug
      row :author
      row :data_source
      row :mobile_translation_id

      if can?(:download, :restricted_content) || permission.blank? || permission&.share_permission_is_granted? || permission&.share_permission_is_unknown?
        row :sqlite_db do
          link_to 'Download', resource.sqlite_db.url if resource.sqlite_db&.url
        end
      end

      row :sqlite_db_generated_at do
        time = resource.sqlite_db_generated_at
        time&.strftime('%B %d, %Y at %I:%M %P %Z')
      end

      row :created_at do
        time = resource.created_at
        time&.strftime('%B %d, %Y at %I:%M %P %Z')
      end
      row :updated_at do
        time = resource.updated_at
        time&.strftime('%B %d, %Y at %I:%M %P %Z')
      end

      if can? :read, ResourcePermission
        row :resource_permission do
          if permission
            link_to "Permission to host: #{permission.permission_to_host} <br> Permission to share: #{permission.permission_to_share}".html_safe, [:admin, permission]
          else
            link_to 'Add', new_admin_resource_permission_path(resource_content_id: resource.id)
          end
        end
      end

      row :resource_info do
        div resource.resource_info.to_s.html_safe
      end

      row :meta_data do
        if resource.meta_data.present?
          pre do
            code do
              JSON.pretty_generate(resource.meta_data)
            end
          end
        end
      end

      row :draft_translations do
        if resource.has_draft_translation?
          if resource.tafsir?
            link_to("View draft tafsirs (#{resource.draft_translations.size} records)", "/admin/draft_tafsirs?q%5Bresource_content_id_eq%5D=#{resource.id}")
          else
            link_to("View draft translations (#{resource.draft_translations.size} records)", "/admin/draft_translations?q%5Bresource_content_id_eq%5D=#{resource.id}")
          end
        else
          'No draft translation imported.'
        end
      end
    end

    panel "Downloadable resources (#{resource.downloadable_resources.size})" do
      table do
        thead do
          td 'ID'
          td 'Name'
          td 'Published'
        end

        tbody do
          resource.downloadable_resources.each do |r|
            tr do
              td link_to(r.id, [:admin, r])
              td r.name
              td r.published?
            end
          end
        end
      end
    end

    active_admin_comments
  end

  form do |f|
    f.inputs 'Resource content Details' do
      f.input :name
      f.input :slug
      f.input :approved
      f.input :language_id,
              as: :searchable_select,
              ajax: { resource: Language }

      f.input :author_id,
              as: :searchable_select,
              ajax: { resource: Author }

      f.input :data_source_id,
              as: :searchable_select,
              ajax: { resource: DataSource }

      f.input :language_name
      f.input :priority
      f.input :mobile_translation_id

      f.input :cardinality_type, as: :select, collection: ResourceContent.collection_for_cardinality_type

      f.input :resource_type
      f.input :resource_id

      f.input :sub_type, as: :select, collection: ResourceContent.collection_for_sub_type
      f.input :resource_info, input_html: { data: { controller: 'tinymce' } }
      f.input :meta_data, input_html: { data: { controller: 'json-editor', json: resource.meta_data } }
    end
    f.actions
  end

  permit_params do
    [
      :name,
      :language_name,
      :approved,
      :language_id,
      :cardinality_type,
      :resource_type,
      :resource_id,
      :sub_type,
      :author_id,
      :data_source_id,
      :slug,
      :priority,
      :mobile_translation_id,
      :resource_info,
      :meta_data,
      tag_ids: []
    ]
  end

  sidebar 'Files for this resource', only: :show do
    if can?(:manage, ResourceContent)
      div do
        render 'admin/upload_file_form'
      end
    end

    table do
      thead do
        th 'Id'
        th 'Name'
        th 'Preview'
      end

      tbody do
        resource.source_files.each do |file|
          tr do
            td file.id
            td file.blob.filename
            td link_to 'View', file.url, target: '_blank'
          end
        end
      end
    end
  end

  sidebar 'Data for this resource', only: :show do
    div do
      if resource.translation?
        link_to 'Translations', "/admin/translations?q%5Bresource_content_id_eq=#{resource.id}"
      elsif resource.tafsir?
        link_to 'Tafsir', "/admin/tafsirs?q%5Bresource_content_id_eq=#{resource.id}"
      elsif resource.transliteration?
        link_to 'transliteration', "/admin/transliterations?q%5Bresource_content_id_eq=#{resource.id}"
      elsif resource.chapter_info?
        link_to 'Chapter info', "/admin/chapter_infos?q%5Bresource_content_id_eq=#{resource.id}"
      elsif resource.tokens?
        link_to 'Quran Text', "/admin/tokens?q%5Bresource_content_id_eq=#{resource.id}"
      elsif resource.video?
        link_to 'Media content', "/admin/media_contents?q%5Bresource_content_id_eq=#{resource.id}"
      elsif resource.foot_note?
        link_to 'Footnotes', "/admin/foot_notes?q%5Bresource_content_id_eq=#{resource.id}"
      elsif resource.topic?
        link_to 'Topics', "/admin/topics"
      elsif resource.recitation?
        if resource.chapter?
          link_to 'Surah recitations',
                  "/admin/audio_chapter_audio_files?q%5Bresource_content_id_eq=#{resource.id}"
        else
          link_to 'Ayah recitations', "/admin/recitations?q%5Bresource_content_id_eq=#{resource.id}"
        end
      elsif resource.mushaf_layout?
        link_to 'Mushaf pages', "/admin/mushaf_pages?q%5Bmushaf_id_eq%5D=#{resource.get_mushaf_id}"
      end
    end
  end

  sidebar 'Export data', only: :show, if: -> { can?(:export, resource) && (resource.translation? || resource.tafsir?) } do
    div do
      render 'admin/export_options'
    end
  end

  sidebar 'Contribution access', only: :show, if: -> { can?(:manage, resource) } do
    table do
      thead do
        th 'id'
        th 'name'
      end

      tbody do
        resource.user_projects.includes(:user).each do |project|
          tr do
            td link_to(project.id, [:admin, project])
            td link_to(project.user.name, [:admin, project.user])
          end
        end
      end
    end
  end

  sidebar 'Tags', only: :show do
    table do
      thead do
        th 'id'
        th 'name'
      end

      tbody do
        resource.tags.each do |tag|
          tr do
            td link_to(tag.id, [:admin, tag])
            td tag.name
          end
        end
      end
    end

    if can?(:manage, Tag)
      div do
        render 'admin/add_tags_form'
      end
    end
  end
end
