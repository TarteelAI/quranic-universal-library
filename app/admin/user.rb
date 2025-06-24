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

  searchable_select_options(
    scope: User,
    text_attribute: :humanize_name,
    filter: lambda do |term, scope|
      scope.ransack(
        first_name_cont: term,
        last_name_cont: term,
        email_cont: term,
        m: 'or'
      ).result
    end
  )

  permit_params do
    permitted = %i[email first_name last_name password]

    if current_user.super_admin?
      permitted += %i[approved confirmed_at locked_at role]
    end

    permitted
  end

  action_item :impersonate, only: :show, if: -> { can?(:impersonate, resource) } do
    link_to impersonate_cms_user_path(resource), method: :put, data: { confirm: 'Are you sure?' } do
      'Impersonate'
    end
  end

  action_item :view_history, only: :show do
    link_to 'History', "/cms/content_changes?q%5Bwhodunnit_cont%5D=User%2F#{resource.id}&order=id_desc"
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

  show do
    attributes_table do
      row :id
      row :first_name
      row :last_name
      row :email
      row :created_at

      if can?(:moderate, resource)
        row :unconfirmed_email
        row :confirmation_sent_at
        row :confirmed_at
        row :failed_attempts
        row :locked_at
        row :remember_created_at
        row :reset_password_sent_at
        row :sign_in_count
        row :role
      end
    end
  end

  form data: { turbo: false } do |f|
    f.inputs 'User Details' do
      f.input :first_name
      f.input :last_name
      f.input :email

      f.input :password, required: false, input_html: {
        data: {
          controller: 'toggle-password'
        }
      }

      if current_user.super_admin?
        f.input :approved
        f.input :confirmed_at, as: :datetime_picker
        f.input :locked_at, as: :datetime_picker
        f.input :role, as: :select, collection: User.roles.keys, selected: resource.role
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
            td link_to project.id, [:cms, project]
            td { link_to(resource.name, [:cms, resource]) if resource }
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
        redirect_to [:cms, resource], notice: 'Updated successfully'
      else
        render action: :edit
      end
    end
  end
end
