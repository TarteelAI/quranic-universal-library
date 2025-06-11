# frozen_string_literal: true

ActiveAdmin.register WordTranslation do
  menu parent: 'Content'
  actions :all, except: :destroy
  includes :language, :word

  ActiveAdminViewHelpers.versionate(self)

  filter :language,
         as: :searchable_select,
         ajax: { resource: Language }
  filter :word,
         as: :searchable_select,
         ajax: { resource: Word }

  index do
    column :id do |resource|
      link_to(resource.id, [:cms, resource])
    end

    column :language, &:language_name
    column :word
    column :text
    actions
  end

  show do
    attributes_table do
      row :id
      row :word
      row :language
      row :text do |resource|
        div class: resource.language_name.to_s.downcase do
          resource.text
        end
      end
      row :resource_content
      row :created_at
      row :updated_at
    end

    ActiveAdminViewHelpers.diff_panel(self, resource) if params[:version]
  end

  permit_params do
    %i[language_id word_id text language_name resource_content_id]
  end

  form do |f|
    f.inputs 'Word Translation Form' do
      f.input :text
      f.input :language_id,
              required: true,
              as: :searchable_select,
              ajax: { resource: Language }
      f.input :word_id
      f.input :language_name
    end
    f.actions
  end
end
