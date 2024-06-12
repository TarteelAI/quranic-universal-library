# frozen_string_literal: true

# == Schema Information
#
# Table name: admin_users
#
#  id                     :integer          not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :inet
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  failed_attempts        :integer          default(0), not null
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :inet
#  locked_at              :datetime
#  name                   :string
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
#  index_admin_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_admin_users_on_email                 (email) UNIQUE
#  index_admin_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_admin_users_on_unlock_token          (unlock_token) UNIQUE
#
ActiveAdmin.register AdminUser do
  menu parent: 'Account', priority: 1

  permit_params :email, :password, :password_confirmation, :name

  action_item :view_history, only: :show do
    link_to 'History', admin_content_changes_path(
      { q: { whodunnit_in: [resource.id, "gid://quran-com-community/AdminUser/#{resource.id}"] } }
    )
  end

  index do
    selectable_column
    id_column
    column :name
    column :email
    column :current_sign_in_at
    column :sign_in_count
    column :created_at
    actions
  end

  filter :email
  filter :name
  filter :current_sign_in_at
  filter :sign_in_count
  filter :created_at

  form data: { turbo: false } do |f|
    f.inputs 'Admin Details' do
      f.input :name
      f.input :email
      f.input :password, required: f.object.new_record?

      if f.object.new_record?
        f.input :password_confirmation
      end
    end

    f.actions
  end

  controller do
    def update
      attributes = permitted_params['admin_user']
      attributes.delete(:password) if attributes[:password].blank?

      if resource.update(attributes)
        redirect_to [:admin, resource], notice: 'Updated successfully'
      else
        render action: :edit
      end
    end
  end
end
