# frozen_string_literal: true

ActiveAdmin.register Mushaf do
  menu parent: 'Quran', priority: 1

  searchable_select_options(
    scope: Mushaf,
    text_attribute: :humanize,
    filter: lambda do |term, scope|
      scope.order('id ASC').ransack(
        id_eq: term,
        name_cont: term,
        m: 'or'
      ).result
    end
  )

  actions :all, except: :destroy

  filter :name
  filter :enabled
  filter :pages_count
  filter :lines_per_page
  filter :qirat_type,
         as: :searchable_select,
         ajax: { resource: QiratType }

  permit_params do
    %i[name description lines_per_page is_default default_font_name enabled default_font_name qirat_type_id pages_count
       resource_content_id]
  end

  index do
    id_column
    column :name
    column :lines_per_page
    column :pages_count
    column :enabled
    column :default_font_name
    column :qirat_type
  end

  show do
    attributes_table do
      row :id
      row :name
      row :description
      row :qirat_type
      row :resource_content
      row :default_font_name
      row :enabled
      row :is_default
      row :lines_per_page
      row :pages_count
      row :lines_count
      row :pdf_url
      row :created_at
      row :updated_at
    end

    active_admin_comments

    panel 'Debugging info' do
      pages = resource.mushaf_pages.order('page_number ASC')
      div 'data-controller': 'peity', 'data-chart': 'line' do
        pages.pluck(:lines_count).join(',')
      end

      h3 "Pages that don't have #{resource.lines_per_page} lines (total #{resource.mushaf_pages.where('lines_count != ?', resource.lines_per_page).count})"
      div do
        pages.where('lines_count != ?', resource.lines_per_page).each do |page|
          span class: 'btn btn-info m-1' do
            span link_to(page.page_number, "/cms/mushaf_page_preview?page=#{page.page_number}&mushaf=#{resource.id}", class: 'text-white')
            span page.lines_count, class: 'badge text-bg-secondary bg-success'
          end
        end
      end

      h3 "Pages where Surah begins"
      div do
        alignments_with_surah = MushafLineAlignment
                                  .where(mushaf: resource)
                                  .with_surah_names
                                  .order('page_number ASC, line_number ASC')

        alignments_with_surah.each do |alignment|
          span class: 'btn btn-info m-1', title: alignment.chapter&.name_simple, data: {controller: 'tooltip'} do
            span link_to(alignment.page_number, "/cms/mushaf_page_preview?page=#{alignment.page_number}&mushaf=#{resource.id}", class: 'text-white')
            span alignment.get_surah_number, class: 'badge text-bg-secondary bg-success'
          end
        end
      end
    end

    panel 'Page preview' do
      div class: 'placeholder' do
        h4 'Select page'

        ul do
          1.upto resource.pages_count do |p|
            li link_to("Page #{p}", "/cms/mushaf_page_preview?page=#{p}&mushaf=#{resource.id}")
          end
        end
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :is_default
      f.input :enabled
      f.input :description
      f.input :lines_per_page
      f.input :pages_count
      f.input :default_font_name
      f.input :qirat_type,
              as: :searchable_select,
              ajax: { resource: QiratType }

      f.input :resource_content_id, as: :searchable_select,
              ajax: { resource: ResourceContent }
    end

    f.actions
  end

  collection_action :export_sqlite_db, method: 'put' do
    authorize! :download, :from_admin

    file_name = params[:file_name].presence || 'quran-data.sqlite'
    mushaf_ids = params[:mushaf_ids].split(',').compact_blank

    Export::MushafLayoutExportJob.perform_later(
      file_name: file_name,
      user_id: current_user.id,
      mushaf_ids: mushaf_ids
    )
    # Restart sidekiq if it's not running
    Utils::System.start_sidekiq

    redirect_back(fallback_location: '/cms', notice: 'Mushaf layouts db will be exported and shared with you on your email shortly')
  end
end
