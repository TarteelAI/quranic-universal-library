# frozen_string_literal: true

ActiveAdmin.register PaperTrail::Version, as: 'ContentChanges' do
  menu parent: 'Content'

  actions :all, except: %i[new edit destroy]

  filter :id
  filter :event
  filter :create_at
  filter :whodunnit
  filter :item_type
  filter :reviewed
  filter :created_at

  index do
    id_column

    column :item do |resource|
      link_to resource.item_type.underscore.humanize, [:cms, resource.item, { version: resource.id }]
    rescue StandardError
      resource.item_type.underscore.humanize
    end

    column :event
    column :created_at
    column :user do |resource|
      if user = GlobalID::Locator.locate(resource.whodunnit)
        link_to "#{user.name}(#{user.email})", [:cms, user]
      end
    end
  end

  action_item :next, only: :show do
    link_to 'Next version', "/cms/content_changes/#{resource.next.id}" if resource.next
  end

  action_item :previous, only: :show do
    link_to 'Previous version', "/cms/content_changes/#{resource.previous.id}" if resource.previous
  end

  action_item :revert, only: :show, if: -> { can? :manage, resource } do
    link_to revert_cms_content_change_path(resource.id), method: :put, data: { confirm: 'Are you sure?' } do
      "Revert #{resource.item_type} to this version!"
    end
  end

  member_action :revert, method: 'put' do
    authorize! :manage, resource

    item = resource.reify
    item.save

    redirect_to [:cms, item], notice: 'Reverted successfully!'
  end

  action_item :toggle_review, only: :show, if: -> { can? :manage, resource } do
    confirm = resource.reviewed? ? "Are you sure to mark this as unreviewed?" : "Are you sure to mark this as reviewed?"

    link_to toggle_review_cms_content_change_path(resource.id), method: :put, data: { confirm: confirm } do
      resource.reviewed? ? 'Not reviewed' : 'Reviewed'
    end
  end

  member_action :toggle_review, method: 'put' do
    authorize! :manage, resource

    if resource.reviewed?
      resource.update(reviewed_by_id: current_user.id, reviewed: false)
    else
      resource.update(reviewed_by_id: current_user.id, reviewed: true)
    end

    redirect_to [:cms, resource], notice: 'Updated'
  end

  show do
    attributes_table 'Version details' do
      row :id
      row :reviewed
      row :reviewed_by_id
      row :item_type do
        if resource.item
          link_to resource.item_type, [:cms, resource.item, { version: resource.index }]
        else
          resource.item_type
        end
      end

      row :event
      row :user do
        if user = GlobalID::Locator.locate(resource.whodunnit)
          begin
            link_to(user.try(:email), [:cms, user])
          rescue StandardError
            'Unknown'
          end
        end
      end
      row :created_at
      row :updated_at
    end

    panel "Attributes of #{resource.item_type} at this version" do
      if resource.event != 'create'
        current = resource.reify

        attributes_table_for current do
          current.attributes.each do |key, _val|
            row key do
              safe_html current.read_attribute(key)
            end
          end
        end
      end
    end

    panel 'Diff with previous version' do
      if previous = resource.previous
        previous = previous.reify
        current  = resource.reify

        attributes_table_for previous do
          current.attributes.each do |key, val|
            row key do
              diff = Diffy::SplitDiff.new(previous.send(key).to_s, val.to_s, format: :html, allow_empty_diff: true)
              "Old <br/> #{diff.left} <br/> New #{diff.right}".html_safe
            end
          end
        end
      else
        "This resource don't have previous version."
      end
    end
  end
end
