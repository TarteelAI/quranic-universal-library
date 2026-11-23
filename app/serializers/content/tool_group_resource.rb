# frozen_string_literal: true

module Content
  # A group of the tools overview (SiteNav::ContributeTools.overview): its heading, its summary and
  # its tools as links to the old tool pages.
  class ToolGroupResource < ApplicationResource
    typelize heading: :string, summary: [:string, { nullable: true }]
    attributes :heading, :summary

    many :tools, resource: SiteNavLinkResource
  end
end
