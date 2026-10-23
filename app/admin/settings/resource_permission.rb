ActiveAdmin.register ResourcePermission do
  menu parent: 'Settings'

  filter :resource_content, as: :searchable_select,
         ajax: { resource: ResourceContent }

  show do
    attributes_table do
      row :id
      row :resource_content
      row :permission_to_host
      row :permission_to_share
      row :permission_to_host_info
      row :permission_to_share_info
      row :source_info
      row :copyright_notice
      row :contact_info
      row :licence
      row :attribution
      row :custom_terms do
        safe_html resource.custom_terms
      end
      row :created_at
      row :updated_at
    end

    active_admin_comments
  end

  permit_params do
    %i[
    resource_content_id
    permission_to_host
    permission_to_share
    contact_info
    permission_to_host_info
    permission_to_share_info
    source_info
    copyright_notice
    licence_id
    attribution
    custom_terms
]
  end

  form do |f|
    f.inputs 'Internal permission notes (not public)' do
      f.input :resource_content_id,
              as: :searchable_select,
              ajax: { resource: ResourceContent }
      f.input :permission_to_host
      f.input :permission_to_share
      f.input :permission_to_host_info
      f.input :permission_to_share_info
      f.input :source_info, as: :text
      f.input :contact_info, as: :text
    end

    f.inputs 'Licence (shown on the resource Licence tab)' do
      f.input :licence, hint: 'Terms, attribution and credits come from the licence'
      f.input :copyright_notice, as: :text, hint: 'Shown as a highlighted notice at the top'
      f.input :attribution, input_html: { rows: 3 }, hint: "Only if this resource needs different wording from the licence's attribution"
      f.input :custom_terms, input_html: { data: { controller: 'tinymce' } }, hint: 'Extra terms for this resource only, shown after the licence terms'
    end

    f.actions
  end

end