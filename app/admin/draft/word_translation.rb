# frozen_string_literal: true

ActiveAdmin.register Draft::WordTranslation do
  menu parent: 'Drafts'

  filter :resource_content, as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :verse, as: :searchable_select,
         ajax: { resource: Verse }
  filter :word, as: :searchable_select,
         ajax: { resource: Word }
  filter :text_matched
  filter :need_review
  filter :imported
  filter :draft_text
  filter :word_group_size

  includes :word,
           :language,
           :resource_content

  action_item :previous_word, only: :show do
    if item = resource.previous_word_translation
      link_to("Previous(#{item.location})", "/cms/draft_word_translations/#{item.id}", class: 'btn')
    end
  end

  action_item :import, only: :show do
    link_to import_cms_draft_word_translation_path(resource), method: :put, data: { confirm: 'Are you sure?' } do
      'Approve and update'
    end if !resource.imported?
  end

  action_item :next_word, only: :show do
    if item = resource.next_word_translation
      link_to "Next(#{item.location})", "/cms/draft_word_translations/#{item.id}", class: 'btn'
    end
  end

  member_action :import, method: 'put' do
    translation = resource.import!

    redirect_to [:cms, translation], notice: 'Draft word translation is approved and imported successfully'
  end

  index do
    id_column
    column :text_matched
    column :need_review
    column :verse_id do |resource|
      link_to(resource.verse.verse_key, [:cms, resource.verse])
    end
    column :word_id, sortable: :location do |resource|
      link_to(resource.location, [:cms, resource.word])
    end
    column :imported
    column :resource do |resource|
      link_to(resource.resource_content.name, [:cms, resource.resource_content])
    end
    column :arabic do |resource|
      div resource.word.text_qpc_hafs, class: 'qpc-hafs'
    end
    column :draft_text
    column :current_text
    column :draft_group_text
    column :word_group_size

    actions
  end

  form do |f|
    f.inputs 'Translation detail' do
      f.input :draft_text
    end

    f.actions
  end

  show do
    language_name = resource.resource_content.language_name

    attributes_table do
      row :id
      row :resource_content
      row :current_text, class: language_name, 'data-controller': 'translation' do
        div do
          span safe_html(resource.current_text)
          span(link_to 'View', [:cms, resource.word_translation]) if resource.word_translation
        end
      end
      row :draft_text, class: language_name, 'data-controller': 'translation', draft: true do
        safe_html resource.draft_text
      end
      row :english_translation do
        WordTranslation.find_by(
          word_id: resource.word_id,
          language_id: 38
        )&.text
      end
      row :text_matched
      row :imported

      row :diff do
        div do
          div Diffy::Diff.new(resource.current_text.to_s, resource.draft_text.to_s, include_plus_and_minus_in_html: true).to_s(:html).html_safe
        end
      end

      row :verse do
        link_to(resource.verse.verse_key, [:cms, resource.verse])
      end
      row :word do
        link_to(resource.word.location, [:cms, resource.word])
      end

      row :created_at
      row :updated_at

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

  sidebar 'Draft translations', only: :index do
    translations = Draft::WordTranslation.new_translations
    selected = params.dig(:q, :resource_content_id_eq).to_i

    translations = translations.sort_by do |t|
      t.id == selected ? 0 : 1
    end

    imported = Draft::WordTranslation.imported_translations.pluck(:id)
    div "Total: #{translations.size}"
    div "Imported: #{imported.size}"

    div class: 'd-flex w-100 flex-column sidebar-item' do
      translations.each do |resource_content|
        div class: "w-100 p-1 border-bottom mb-3 #{'selected' if selected == resource_content.id}" do
          div class: 'flex-between' do
            span link_to(resource_content.id, [:cms, resource_content], target: 'blank')
            imported.include?(resource_content.id) ? span('imported', class: 'status_tag yes ms-2') : ''
          end

          div "#{resource_content.name}(#{resource_content.language_name})"
          div "Synced: #{resource_content.meta_value('synced-at')} Updated: #{resource_content.updated_at}"

          div class: 'd-flex my-2 flex-between gap-2' do
            span(link_to 'Filter', "/cms/draft_word_translations?q%5Bresource_content_id_eq%5D=#{resource_content.id}", class: 'mb-2 btn btn-sm btn-info text-white')
            issue_count = AdminTodo.where(resource_content_id: resource_content.id).count

            if can?(:manage, :draft_content) || current_user.super_admin?
              span(link_to 'Approve', import_draft_cms_resource_content_path(resource_content, approved: true), method: 'put', class: 'btn btn-sm btn-danger text-white', data: { confirm: 'Are you sure to import this translations?' })
              if issue_count > 0
                span(link_to "Issues #{issue_count}", "/cms/admin_todos?q%5Bresource_content_id_eq%5D=#{resource_content.id}&order=id_desc", class: 'btn btn-sm btn-warning text-white')
              end
              span(link_to 'Delete', import_draft_cms_resource_content_path(resource_content, remove_draft: true), method: 'put', class: 'btn btn-sm btn-danger text-white', data: { confirm: 'Are you sure to remove draft translations?' })
            end
          end
        end
      end
    end
  end

  permit_params do
    %i[
      draft_text
    ]
  end
end
