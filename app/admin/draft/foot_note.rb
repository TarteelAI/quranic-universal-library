# frozen_string_literal: true

ActiveAdmin.register Draft::FootNote do
  menu parent: 'Drafts'

  filter :resource_content,
         as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :text_matched

  index do
    id_column
    column :translation do |resource|
      link_to resource.draft_translation_id, cms_draft_translation_path(resource.draft_translation_id)
    end

    column :text_matched
    column :text do |resource|
      resource.draft_text.first(50)
    end

    actions
  end

  show do
    attributes_table do
      row :id
      row :resource_content
      row :draft_translation
      row :footnote

      row :draft_text do
        safe_html  resource.draft_text
      end

      row :current_text do
        safe_html resource.current_text
      end
      row :text_matched

      row :diff do
        div Diffy::Diff.new(resource.current_text.to_s, resource.draft_text.to_s).to_s(:html_simple).html_safe
      end

      row :created_at
      row :updated_at
    end
  end

  form data: {turbo: false} do |f|
    f.inputs 'Footnote detail' do
      f.input :draft_text
      f.input :draft_translation_id
    end

    f.actions
  end

  permit_params do
    %i[
      draft_text
      draft_translation_id
    ]
  end
end
