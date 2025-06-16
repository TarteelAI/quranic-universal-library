# frozen_string_literal: true

ActiveAdmin.register Draft::Content do
  menu parent: 'Drafts'

  filter :location
  filter :chapter, as: :searchable_select,
         ajax: { resource: Chapter }
  filter :verse, as: :searchable_select,
         ajax: { resource: Verse }
  filter :word, as: :searchable_select,
         ajax: { resource: Word }
  filter :resource_content, as: :searchable_select,
         ajax: { resource: ResourceContent }
  filter :text_matched
  filter :need_review
  filter :imported
  filter :draft_text
  filter :text

  includes :resource_content

  index do
    id_column
    column :location
    column :text_matched
    column :need_review
    column :imported
    column :resource do |resource|
      link_to(resource.resource_content.name, [:cms, resource.resource_content])
    end
    column :draft_text, sortable: :draft_text do |resource|
      resource.draft_text.to_s.first(50)
    end

    column :current_text, sortable: :current_text do |resource|
      resource.current_text.to_s.first(50)
    end

    actions
  end

  form do |f|
    f.inputs 'Translation detail' do
      f.input :draft_text
    end

    f.actions
  end

  show do
    language = resource.resource_content.language
    language_name = language&.name.to_s.downcase

    attributes_table do
      row :id
      row :location
      row :chapter
      row :verse
      row :word
      row :resource_content
      row :current_text, class: language_name, 'data-controller': 'translation' do
        div do
          span resource.current_text.to_s.html_safe
        end
      end
      row :draft_text do
        div(class: language_name, 'data-controller': 'translation', 'data-draft': true, lang: language&.iso_code) do
          resource.draft_text.to_s.html_safe
        end
      end
      row :text_matched
      row :imported

      row :diff do
        div do
          div Diffy::Diff.new(resource.current_text.to_s, resource.draft_text.to_s, include_plus_and_minus_in_html: true).to_s(:html).html_safe
        end
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

  permit_params do
    %i[
      draft_text
    ]
  end
end
