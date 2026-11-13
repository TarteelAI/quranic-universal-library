# frozen_string_literal: true

# Resource requests sent from the new pages: editors set the status visitors see and hide a
# request from the public list. Requests are not created or removed here. Admins only (Ability),
# because a request names its author.
ActiveAdmin.register ResourceRequest do
  menu parent: 'Settings', label: 'Resource requests'
  actions :index, :show, :edit, :update

  scope :all, default: true
  scope('Visible', &:visible)
  scope('Hidden') { |requests| requests.where(hidden: true) }

  filter :title
  filter :resource_type
  filter :status, as: :select, collection: -> { ResourceRequest::STATUSES.invert }
  filter :hidden
  filter :created_at

  includes :user, :votes

  index do
    id_column
    column :title
    column :resource_type
    column :language
    column(:status, &:status_label)
    column :hidden
    column(:votes) { |request| request.votes.size }
    column :user
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :title
      row :description
      row :resource_type
      row :language
      row(:status, &:status_label)
      row :hidden
      row(:votes) { |request| request.votes.size }
      row(:author) { |request| request.user&.email }
      row :created_at
      row :updated_at
    end
    active_admin_comments
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)
    f.inputs do
      f.input :status, as: :select, collection: ResourceRequest::STATUSES.invert, include_blank: false
      f.input :hidden, hint: 'Hidden requests are left out of the public list and cannot be voted on.'
    end
    f.actions
  end

  permit_params :status, :hidden
end
