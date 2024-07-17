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
]
  end

  form do |f|
    f.inputs 'Permission detail' do
      f.input :resource_content_id,
              as: :searchable_select,
              ajax: { resource: ResourceContent }
      f.input :permission_to_host
      f.input :permission_to_share
      f.input :permission_to_host_info
      f.input :permission_to_share_info
      f.input :source_info, as: :text
      f.input :copyright_notice, as: :text
    end

    f.actions
  end

end