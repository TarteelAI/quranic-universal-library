ActiveAdmin.register DownloadableResourceTag do
  menu parent: 'Downloads', priority: 5

  filter :name
  filter :glossary_term

  index do
    id_column
    column :name
    column :glossary_term

    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :glossary_term
      row :description do
        resource.description.to_s.html_safe
      end
      row :created_at
      row :updated_at
    end

    active_admin_comments
  end

  permit_params do
    %i[name glossary_term description]
  end

  form do |f|
    f.inputs 'Resource tag Details' do
      f.input :name
      f.input :glossary_term
      f.input :description, input_html: { data: { controller: 'tinymce' } }
    end

    f.actions
  end

end