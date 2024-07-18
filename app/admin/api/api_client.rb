# frozen_string_literal: true

# == Schema Information
#
# Table name: char_types
#
#  id          :integer          not null, primary key
#  description :text
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  parent_id   :integer
#
# Indexes
#
#  index_char_types_on_parent_id  (parent_id)
#
ActiveAdmin.register ApiClient do
  menu parent: 'Settings', priority: 10
  actions :all, except: :destroy

  filter :name
  filter :active
  filter :created_at
  filter :api_key

  show do
    attributes_table do
      row :id
      row :name
      row :api_key
      row :active
      row :request_quota
      row :requests_count
      row :current_period_requests_count
      row :current_period_ends_at
      row :created_at
      row :updated_at
    end
    active_admin_comments

    panel 'Request stats' do
      table border: 1 do
        thead do
          th '#'
          th 'Date'
          td 'Count'
        end

        tbody do
          resource.api_client_request_stats.order('date DESC').each_with_index do |stats, i|
            tr do
              td i+1
              td stats.date
              td stats.requests_count
            end
          end
        end
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :name, required: true
      f.input :api_key
      f.input :active
      f.input :request_quota
    end

    f.actions
  end

  permit_params do
    %i[
    name
    api_key
    kalimat_api_key
    internal_api
    active
    request_quota
   ]
  end
end