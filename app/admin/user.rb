# frozen_string_literal: true

ActiveAdmin.register User do
  menu parent: 'Account', priority: 1

  filter :first_name
  filter :last_name
  filter :email
  filter :approved, if: proc { |context| context.current_user.super_admin? }
  filter :created_at, if: proc { |context| context.current_user.super_admin? }
  filter :locked_at, if: proc { |context| context.current_user.super_admin? }
  filter :confirmed_at, if: proc { |context| context.current_user.super_admin? }

  permit_params do
    permitted = %i[email first_name last_name password]

    if current_user.super_admin?
      permitted << %i[approved confirmed_at locked_at]
    end

    permitted
  end

  action_item :impersonate, only: :show, if: -> { can?(:impersonate, resource) } do
    link_to impersonate_admin_user_path(resource), method: :put, data: { confirm: 'Are you sure?' } do
      'Impersonate'
    end
  end

  action_item :view_history, only: :show do
    filter = {
      whodunnit_in: [
        resource.id,
        "gid://quran-com-community/User/#{resource.id}"
      ]
    }

    link_to 'History', admin_content_changes_path({ q: filter })
  end

  member_action :impersonate, method: 'put' do
    authorize! :impersonate, User
    warden.set_user(resource, { scope: :user, run_callbacks: false })
  end

  index do
    selectable_column
    id_column
    column :email
    column :first_name
    column :last_name
    column :approved if current_user.super_admin?

    column :created_at
    actions
  end

  form data: { turbo: false } do |f|
    f.inputs 'User Details' do
      f.input :first_name
      f.input :last_name
      f.input :email
      f.input :password, required: false

      if current_user.super_admin?
        f.input :approved
        f.input :confirmed_at, as: :datetime_picker
        f.input :locked_at, as: :datetime_picker
      end
    end

    f.actions
  end

  sidebar 'Projects', only: :show, if: -> { can?(:assign_project, resource) } do
    div do
      render 'admin/user_project_form'
    end

    table do
      thead do
        td :id
        td :name
      end

      tbody do
        resource.user_projects.each do |project|
          tr do
            resource = project.get_resource_content
            td link_to project.id, [:admin, project]
            td { link_to(resource.name, [:admin, resource]) if resource }
          end
        end
      end
    end
  end

  controller do
    def update
      attributes = permitted_params['user']
      attributes.delete(:password) if attributes[:password].blank?

      if resource.update(attributes)
        redirect_to [:admin, resource], notice: 'Updated successfully'
      else
        render action: :edit
      end
    end
  end
end
