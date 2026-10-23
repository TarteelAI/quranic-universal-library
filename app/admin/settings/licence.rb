ActiveAdmin.register Licence do
  menu parent: 'Settings'
  actions :all, except: :destroy

  filter :name
  filter :short_name
  filter :created_at

  index do
    id_column
    column :name
    column :short_name
    column :url
    column :resources do |licence|
      licence.resource_permissions.size
    end
    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :short_name
      row :url
      row :summary
      row :allowed do
        simple_format licence.allowed
      end
      row :allowed_with_permission do
        simple_format licence.allowed_with_permission
      end
      row :prohibited do
        simple_format licence.prohibited
      end
      row :conditions do
        simple_format licence.conditions
      end
      row :terms do
        safe_html licence.terms
      end
      row :attribution
      row :copyright_holders do
        simple_format licence.copyright_holders
      end
      row :contact
      row :credits do
        safe_html licence.credits
      end
      row :special_thanks do
        safe_html licence.special_thanks
      end
      row :created_at
      row :updated_at
    end

    panel "Resources using this licence (#{licence.resource_permissions.size})" do
      div class: 'mb-3' do
        link_to 'Add resources', '#_',
                class: 'button',
                data: { controller: 'ajax-modal', css_class: 'modal-lg', url: add_resources_cms_licence_path(licence) }
      end

      permissions = licence.resource_permissions.index_by(&:resource_content_id)

      table_for licence.resource_contents.order(:sub_type, :name) do
        column :id
        column :name do |content|
          link_to content.name, [:cms, content]
        end
        column :type, &:sub_type
        column :language, &:language_name
        column :own_attribution do |content|
          permissions[content.id].attribution.present? ? 'Yes' : ''
        end
        column '' do |content|
          safe_join([
            link_to('Edit permission', [:edit, :cms, permissions[content.id]]),
            link_to('Remove', remove_resource_cms_licence_path(licence, resource_content_id: content.id),
                    method: :delete, class: 'text-danger',
                    data: { confirm: "Remove #{content.name} from this licence?" })
          ], ' · ')
        end
      end
    end

    active_admin_comments
  end

  action_item :delete_licence, only: :show, if: -> { can? :destroy, resource } do
    link_to 'Delete Licence', '#_',
            class: 'text-danger',
            data: { controller: 'ajax-modal', url: confirm_delete_cms_licence_path(resource) }
  end

  member_action :confirm_delete, method: :get do
    authorize! :destroy, resource

    render partial: 'admin/confirm_delete_licence', locals: { licence: resource }
  end

  member_action :destroy_licence, method: :delete do
    authorize! :destroy, resource

    # Case-sensitive, only surrounding whitespace is ignored.
    if params[:confirm_name].to_s.strip != resource.name
      return redirect_to [:cms, resource], alert: "The name you typed doesn't match, nothing was deleted."
    end

    name = resource.name
    resource.destroy!

    redirect_to cms_licences_path, notice: "#{name} has been deleted."
  end

  member_action :add_resources, method: %i[get post] do
    if request.post?
      ids = Array(params[:resource_content_ids]).reject(&:blank?).map(&:to_i)
      resource.add_resource_contents(ids)

      redirect_to [:cms, resource], notice: "Added #{ids.size} #{'resource'.pluralize(ids.size)} to this licence."
    else
      query = params[:q].to_s.strip
      type = params[:type].presence
      linked = resource.resource_permissions.pluck(:resource_content_id)

      contents = ResourceContent.where.not(id: linked).order(:sub_type, :name).limit(50)
      contents = contents.where(sub_type: type) if type
      if query.present?
        contents = query.match?(/\A\d+\z/) ? contents.where(id: query) : contents.where('name ILIKE :q OR language_name ILIKE :q', q: "%#{query}%")
      end
      other_licences = ResourcePermission.where(resource_content_id: contents.map(&:id)).where.not(licence_id: nil).includes(:licence).index_by(&:resource_content_id)

      locals = { licence: resource, contents: contents, other_licences: other_licences, query: query, type: type }

      if turbo_frame_request?
        render partial: 'admin/licence_resource_results', locals: locals
      else
        render partial: 'admin/licence_add_resources', locals: locals
      end
    end
  end

  member_action :remove_resource, method: :delete do
    resource.remove_resource_content(params[:resource_content_id].to_i)
    redirect_to [:cms, resource], notice: 'Resource removed from this licence.'
  end

  permit_params do
    %i[
      name
      short_name
      url
      summary
      allowed
      allowed_with_permission
      prohibited
      conditions
      terms
      attribution
      copyright_holders
      contact
      credits
      special_thanks
    ]
  end

  form do |f|
    f.inputs 'Licence' do
      f.input :name, hint: 'e.g. Creative Commons Attribution 4.0 International'
      f.input :short_name, hint: 'e.g. CC BY 4.0'
      f.input :url, hint: 'Link to the official licence text, if there is one'
      f.input :summary, as: :text, input_html: { rows: 3 }, hint: 'One or two plain sentences'
    end

    f.inputs 'What users can do (one item per line)' do
      f.input :allowed, input_html: { rows: 5 }, hint: 'e.g. Personal use'
      f.input :allowed_with_permission, input_html: { rows: 4 }, hint: 'Allowed only after asking the copyright holder'
      f.input :prohibited, input_html: { rows: 5 }, hint: 'e.g. Selling the font'
      f.input :conditions, input_html: { rows: 3 }, hint: 'Rules that apply to every use, e.g. No ads'
    end

    f.inputs 'Attribution and credits' do
      f.input :attribution, input_html: { rows: 3 }, hint: 'Plain text users should copy into their app or site. A resource can override it.'
      f.input :copyright_holders, input_html: { rows: 4 }, hint: 'One per line'
      f.input :contact, hint: 'Public email or link for permission requests'
      f.input :credits, input_html: { data: { controller: 'tinymce' } }
      f.input :special_thanks, input_html: { data: { controller: 'tinymce' } }
    end

    f.inputs 'Full terms' do
      f.input :terms, input_html: { data: { controller: 'tinymce' } }
    end

    f.actions
  end
end
