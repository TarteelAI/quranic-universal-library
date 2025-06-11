ActiveAdmin.register DownloadableResourceTag do
  menu parent: 'Downloads', priority: 5

  filter :name
  filter :glossary_term

  searchable_select_options(
    scope: DownloadableResourceTag,
    text_attribute: :name,
    filter: lambda do |term, scope|
      scope.ransack(
        name_cont: term,
        m: 'or'
      ).result
    end
  )

  index do
    id_column
    column :name
    column :slug
    column :glossary_term
    column :color_class

    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :slug
      row :glossary_term
      row :description do
        safe_html resource.description
      end
      row :color_class
      row :created_at
      row :updated_at
    end

    panel 'Resources' do
      table do
        thead do
          th 'Id'
          th 'Name'
          th 'Type'
          th 'Actions'
        end

        tbody do
          resource.downloadable_resources.each do |r|
            tr do
              td link_to(r.id, [:cms, r])
              td r.name
              td r.resource_type
              td link_to 'View', [:cms, r], target: '_blank'
            end
          end
        end
      end
    end

    active_admin_comments
  end

  permit_params do
    %i[name glossary_term slug description color_class]
  end

  form do |f|
    f.inputs 'Resource tag Details' do
      f.input :name
      f.input :slug
      f.input :glossary_term
      f.input :color_class, as: :select, collection: ['red', 'green', 'blue', 'orange', 'yellow']
      f.input :description, input_html: { data: { controller: 'tinymce' } }
    end

    f.actions
  end
end