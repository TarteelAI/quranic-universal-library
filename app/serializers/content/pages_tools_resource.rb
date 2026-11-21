# frozen_string_literal: true

module Content
  # Props of the tools overview (Content::PagesController#tools).
  class PagesToolsResource < ApplicationResource
    many :groups, resource: ToolGroupResource
  end
end
