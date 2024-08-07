# frozen_string_literal: true

# == Schema Information
#
# Table name: resource_contents
#
#  id                     :integer          not null, primary key
#  approved               :boolean
#  author_name            :string
#  cardinality_type       :string
#  description            :text
#  language_name          :string
#  meta_data              :jsonb
#  name                   :string
#  priority               :integer
#  resource_info          :text
#  resource_type          :string
#  resource_type_name     :string
#  slug                   :string
#  sqlite_db              :string
#  sqlite_db_generated_at :datetime
#  sub_type               :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  author_id              :integer
#  data_source_id         :integer
#  language_id            :integer
#  mobile_translation_id  :integer
#  resource_id            :string
#
# Indexes
#
#  index_resource_contents_on_approved               (approved)
#  index_resource_contents_on_author_id              (author_id)
#  index_resource_contents_on_cardinality_type       (cardinality_type)
#  index_resource_contents_on_data_source_id         (data_source_id)
#  index_resource_contents_on_language_id            (language_id)
#  index_resource_contents_on_meta_data              (meta_data) USING gin
#  index_resource_contents_on_mobile_translation_id  (mobile_translation_id)
#  index_resource_contents_on_priority               (priority)
#  index_resource_contents_on_resource_id            (resource_id)
#  index_resource_contents_on_resource_type_name     (resource_type_name)
#  index_resource_contents_on_slug                   (slug)
#  index_resource_contents_on_sub_type               (sub_type)
#
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
    end)

  menu parent: 'Content', priority: 1
  actions :all, except: :destroy

  scope :with_footnotes
  scope :from_quranenc
  scope :approved

  filter :name
  filter :approved
  filter :quran_enc_key, as: :string
  filter :slug, as: :string
  filter :data_source_id, as: :searchable_select,
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
  filter :language_id, as: :searchable_select,
         ajax: { resource: Language }
  #filter :tags_id, as: :searchable_select, multiple: true,
  #       ajax: { resource: Tag }

  ActiveAdminViewHelpers.render_translated_name_sidebar(self)

  action_item :approve, only: :show do
    link_to approve_admin_resource_content_path(resource), method: :put, data: { confirm: 'Are you sure?' } do
      resource.approved? ? 'Un Approve!' : 'Approve!'
    end
  end

  action_item :import_draft, only: :show do
    if resource.sourced_from_quranenc?
      type = resource.tafsir? ? 'tafsir' : 'translation'
      link_to "Import Draft #{type}", import_draft_admin_resource_content_path(resource), method: :put,
              data: { confirm: "Are you sure to import #{type} for this resource from QuranEnc?" }
    end
  end

  member_action :upload_file, method: 'post' do
    permitted = params.require(:resource_content).permit source_files: []

    permitted['source_files'].each do |attachment|
      resource.source_files.attach(attachment)
    end

    redirect_to [:admin, resource], notice: 'File saved successfully'
  end

  member_action :approve, method: 'put' do
    resource.toggle_approve!

    redirect_to [:admin, resource], notice: resource.approved? ? 'Approved successfully' : 'Un approved successfully'
  end

  member_action :validate_draft, method: 'get' do
    @resource = resource
    @issues = resource.check_for_missing_draft_tafsirs
    render partial: 'admin/validate_draft_tafsir'
  end

  member_action :import_draft, method: 'put' do
    if !current_user.super_admin?
      return redirect_back fallback_location: "/admin/draft_tafsirs?q%5Bresource_content_id_eq%5D=#{resource.id}", alert: 'Sorry, you can not perform this action'
    end

    if params[:approved]
      QuranEnc::ApproveDraftTranslationJob.perform_later(resource.id)

      redirect_to [:admin, resource], notice: "This #{resource.tafsir? ? 'tafsir' : 'translation'} will be imported shortly!"
    elsif params[:remove_draft]
      QuranEnc::ApproveDraftTranslationJob.perform_later(resource.id, remove_draft: true)

      redirect_to [:admin, resource], notice: 'Draft translations are removed successfully'
    else
      QuranEnc::ImportDraftTranslationJob.perform_later(resource.id)

      redirect_to [:admin, resource], notice: "System will re-sync this translation from QuranEnc shortly."
    end
  end

  member_action :export, method: 'put' do
    permitted = params.require(:resource_content).permit(:export_file_name, :include_footnote, :export_format).to_h
    export_type = permitted[:export_format].to_s.strip

    if export_type == 'sqlite'
      ExportTranslationJob.perform_later(resource.id, permitted[:export_file_name], permitted[:include_footnote] == 'true', current_user.id)
    elsif export_type == 'raw_files'
      Export::RawTrafsirJob.perform_later(resource.id, permitted[:export_file_name], current_user.id)
    elsif ['json_nested_array', 'json_text_chunks'].include?(export_type)
      Export::TranslationJson.perform_later(resource.id, current_user.id, export_type == 'json_nested_array')
    elsif export_type == 'tafsir_json'
      if resource.tafsir?
        Export::TafsirJson.perform_later(resource.id, permitted[:export_file_name].to_s.strip, current_user.id)
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

  def scoped_collection
    super.includes :language
  end

  sidebar 'Files for this resource', only: :show do
    div do
      render 'admin/upload_file_form'
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
        link_to 'Mushaf pages', "/admin/mushaf_pages?q%5Bmushaf_id_eq%5D=#{Mushaf.where(resource_content_id: resource.id).first&.id}"
      end
    end
  end

  sidebar 'Export data', only: :show, if: -> { resource.translation? || resource.tafsir? } do
    div do
      render 'admin/export_options'
    end
  end

  sidebar 'Contribution access', only: :show do
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

    div do
      render 'admin/add_tags_form'
    end
  end
end
