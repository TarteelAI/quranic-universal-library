# frozen_string_literal: true

ActiveAdmin.register UserProject do
  menu parent: 'Account', priority: 1

  filter :user,
         as: :searchable_select,
         ajax: { resource: User }

  filter :approved

  permit_params do
    %i[user_id resource_content_id description admin_notes approved]
  end

  controller do
    before_action :prevent_self_assignment, only: %i[create update]

    def update
      attributes = permitted_params['user_project']
      resource.attributes = attributes
      resource.save(validate: false)

      redirect_to [:cms, resource], notice: 'Updated successfully'
    end

    protected

    # Moderators can manage projects, but not grant or edit access for themselves
    def prevent_self_assignment
      return if current_user.super_admin? || current_user.is_admin?

      target_user_id = params.dig(:user_project, :user_id).presence&.to_i
      own_project = params[:id].present? && resource.user_id == current_user.id

      if own_project || target_user_id == current_user.id
        redirect_back fallback_location: cms_user_projects_path,
                      alert: "You can't create or change a project for your own account."
      end
    end
  end

  form do |f|
    f.inputs 'User project Details' do
      f.input :approved
      f.input :user_id

      f.input :description
      f.input :admin_notes

      f.input :resource_content,
              as: :searchable_select,
              ajax: { resource: ResourceContent }
    end

    f.actions
  end
end
