# frozen_string_literal: true

ActiveAdmin.register Draft::Tafsir do
  menu parent: 'Drafts'

  filter :resource_content,
         as: :searchable_select,
         ajax: { resource: ResourceContent }

  filter :verse,
         as: :searchable_select,
         ajax: { resource: Verse }

  filter :group_tafsir,
         as: :searchable_select,
         ajax: { resource: Verse }

  filter :text_matched
  filter :need_review
  filter :reviewed
  filter :imported
  filter :group_verses_count

  action_item :import, only: :show do
    link_to import_admin_draft_tafsir_path(resource), method: :put, data: { confirm: 'Are you sure?' } do
      'Approve and update'
    end if !resource.imported?
  end

  member_action :import, method: 'put' do
    tafsir = resource.import!

    redirect_to [:admin, tafsir], notice: 'Draft Tafsir is approved and imported successfully'
  end

  action_item :previous, only: :show do
    if item = resource.previous_ayah_tafsir
      link_to("Previous(#{item.start_verse.verse_key})", "/admin/draft_tafsirs/#{item.id}", class: 'btn') if item
    end
  end

  action_item :next, only: :show do
    if item = resource.next_ayah_tafsir
      link_to "Next(#{item.start_verse.verse_key})", "/admin/draft_tafsirs/#{item.id}", class: 'btn'
    end
  end

  index do
    id_column
    column :text_matched
    column :need_review
    column :reviewed
    column :from, sortable: :start_verse_id do |resource|
      span resource.group_verse_key_from, class: "status_tag #{'yes' if resource.verse_key == resource.group_verse_key_from}"
    end
    column :to, sortable: :end_verse_id do |resource|
      resource.group_verse_key_to
    end

    column :verse, sortable: :verse_id do |resource|
      link_to resource.verse.verse_key, [:admin, resource.verse] if resource.verse
    end
    column :imported
    column :text do |resource|
      resource.draft_text.to_s.first(50)
    end
    column :grp_size, sortable: :group_verses_count do |resource|
      resource.group_verses_count
    end

    actions
  end

  form do |f|
    f.inputs 'Tafsir detail' do
      f.input :draft_text, input_html: { data: { controller: 'tinymce' } }
      f.input :need_review
      f.input :reviewed

      f.input :start_verse_id,
              as: :searchable_select,
              ajax: { resource: Verse }

      f.input :end_verse_id,
              as: :searchable_select,
              ajax: { resource: Verse }

      f.input :group_tafsir_id,
              as: :searchable_select,
              ajax: { resource: Verse }
    end

    f.actions
  end

  show do
    language_name = resource.resource_content.language_name

    attributes_table do
      row :id
      row :resource_content
      row :user

      row :tafsir do
        tafsir = resource.original_tafsir

        if tafsir
          link_to tafsir.id, [:admin, tafsir]
        end
      end

      row :group_verse_key_from
      row :group_verse_key_to

      row :group_tafsir do |resource|
        if resource.group_tafsir
          div do
            span link_to(resource.group_tafsir.verse_key, [:admin, resource.group_tafsir]), class: 'mr-4'
            span(link_to('View group tafsir', [:admin, resource.main_group_tafsir])) if resource.main_group_tafsir
          end
        end
      end

      row :group_verses_count

      row :text_matched
      row :imported
      row :need_review
      row :reviewed
      row :comments

      row :created_at
      row :updated_at

      row :verse do
        div do
          link_to(resource.verse.verse_key, [:admin, resource.verse])

          div class: 'arabic qpc-hafs' do
            resource.verse.text_qpc_hafs
          end
        end
      end

      row :text do
        div class: 'row', style: "display: flex !important" do
          div class: 'col-6', style: "border-right: 1px dotted #000;" do
            h4 "New text"
            div resource.draft_text.to_s.html_safe, class: "tafsir p-2 #{language_name}"
          end

          div class: 'col-6' do
            h4 "Current text"
            div resource.current_text.to_s.html_safe, class: "tafsir p-2 #{language_name}"
          end
        end
      end

      row :diff do
        div Diffy::Diff.new(resource.current_text.to_s, resource.draft_text.to_s).to_s(:html).html_safe
      end

      row :quran_enc_link do
        resource_content = resource.resource_content
        verse = resource.verse
        div do
          link_to('View on QuranEnc',
                  "https://quranenc.com/en/browse/#{resource_content.quran_enc_key}/#{verse.verse_key.sub(':', '/')}",
                  target: '_blank',
                  rel: 'noopener')
        end
      end

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
    end
  end

  sidebar 'Draft tafsirs', only: :index do
    tafisrs = Draft::Tafsir.new_tafsirs
    imported = Draft::Tafsir.imported.pluck(:id)
    selected = params.dig(:q, :resource_content_id_eq).to_i
    div "Total: #{tafisrs.size}"
    div "Imported: #{imported.size}"

    tafisrs = tafisrs.sort_by do |t|
      t.id == selected ? 0 : 1
    end

    div class: 'd-flex w-100 flex-column sidebar-item' do
      tafisrs.each do |resource_content|
        div class: "w-100 p-1 flex-between border-bottom mb-3 #{'selected' if selected == resource_content.id}"  do
          div do
            span link_to(resource_content.id, [:admin, resource_content], target: 'blank')
            imported.include?(resource_content.id) ? span('imported', class: 'status_tag yes ms-2') : ''
          end

          div "#{resource_content.name}(#{resource_content.language_name})"
          div "Synced: #{resource_content.meta_value('synced-at')} Updated: #{resource_content.updated_at}"

          div class: 'd-flex my-2 flex-between gap-2' do
              span(link_to 'Filter', "/admin/draft_tafsirs?q%5Bresource_content_id_eq%5D=#{resource_content.id}", class: 'btn btn-sm btn-info text-white')

              if can?(:manage, :draft_content)
                span(link_to 'Validate', validate_draft_admin_resource_content_path(resource_content), class: 'btn btn-sm btn-success text-white', data: { controller: 'ajax-modal', url: validate_draft_admin_resource_content_path(resource_content) })
                span(link_to 'Compare grouping', compare_ayah_grouping_admin_resource_content_path(resource_content), class: 'btn btn-sm btn-success text-white', data: { controller: 'ajax-modal', url: compare_ayah_grouping_admin_resource_content_path(resource_content) })

                span(link_to 'Approve', import_draft_admin_resource_content_path(resource_content, approved: true), method: 'put', class: 'btn btn-sm btn-warning text-white', data: { confirm: 'Are you sure to import this tafsir?' })
                span(link_to 'Delete', import_draft_admin_resource_content_path(resource_content, remove_draft: true), method: 'put', class: 'btn btn-sm btn-danger text-white', data: { confirm: 'Are you sure to remove draft tafsir?' })
              end
            end
        end
      end
    end
  end

  controller do
    def update
      super
      resource.update_ayah_grouping
    end
  end

  permit_params do
    %i[
      draft_text
      start_verse_id
      end_verse_id
      group_tafsir_id
    ]
  end
end
