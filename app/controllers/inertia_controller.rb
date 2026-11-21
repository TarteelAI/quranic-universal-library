# frozen_string_literal: true

# Base controller for the Inertia pages in app/frontend/pages. AGENTS.md ("Conventions for a
# new page") describes how pages use it.
class InertiaController < ApplicationController
  include Alba::Inertia::Controller

  layout 'inertia'

  inertia_share { SharedPropsResource.new(shared_props).to_inertia }

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def shared_props
    { auth: { user: current_user }, nav: SiteNav.new(tools: helpers.developer_tools) }
  end

  def page_meta(**options)
    PageMeta.new(path: request.path, **options).tags
  end

  def render_not_found
    render_inertia 'errors/ErrorPage',
                   serializer: ErrorPageResource,
                   locals: { status: 404 },
                   status: :not_found,
                   meta: page_meta(title: 'Page not found - QUL', robots: 'noindex')
  end
end
