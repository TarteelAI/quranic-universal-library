# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  about_me               :text
#  approved               :boolean          default(FALSE)
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :inet
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  failed_attempts        :integer          default(0), not null
#  first_name             :string
#  last_name              :string
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :inet
#  locked_at              :datetime
#  projects               :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer          default(0), not null
#  unconfirmed_email      :string
#  unlock_token           :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_unlock_token          (unlock_token) UNIQUE
#
ActiveAdmin.register User do
  menu parent: 'Account', priority: 1

  permit_params :email, :first_name, :last_name, :password, :approved, on: :user

  action_item :impersonate, only: :show do
    link_to impersonate_admin_user_path(resource), method: :put, data: { confirm: 'Are you sure?' } do
      'Impersonate'
    end
  end

  action_item :view_history, only: :show do
    link_to 'History',
            admin_content_changes_path({ q: { whodunnit_in: [resource.id,
                                                             "gid://quran-com-community/User/#{resource.id}"] } })
  end

  member_action :impersonate, method: 'put' do
    warden.set_user(resource, { scope: :user, run_callbacks: false })
  end

  index do
    selectable_column
    id_column
    column :email
    column :first_name
    column :last_name
    column :approved

    column :created_at
    actions
  end

  filter :first_name
  filter :email
  filter :approved
  filter :created_at

  form do |f|
    f.inputs 'User Details' do
      f.input :first_name
      f.input :last_name
      f.input :email
      f.input :password, required: false
      f.input :approved
    end
    f.actions
  end

  sidebar 'Projects', only: :show do
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
