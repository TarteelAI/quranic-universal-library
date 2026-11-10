# frozen_string_literal: true

module Catalog
  # Props of a resource detail page (Catalog::ResourcesController#show), from a
  # Catalog::ResourcePage. The preview is deferred so the first response does not wait for it.
  class ResourcesShowResource < ApplicationResource
    one :resource, source: proc { self[:page].resource }, resource: ResourceDetailResource
    one :type, source: proc { self[:page].type }, resource: TypeResource
    many :statuses, source: proc { Taxonomy.statuses }, resource: OptionResource
    many :files, source: proc { self[:page].files }, resource: ResourceFileResource
    many :facts, source: proc { self[:page].facts }, resource: ResourceFactResource
    many :works_with, source: proc { self[:page].works_with }, resource: WorksWithGroupResource
    many :changelog, source: proc { self[:page].changelog }, resource: ResourceChangeResource

    typelize licence: { nullable: true }
    one :licence, source: proc { self[:page].licence }, resource: ResourceLicenceResource

    typelize tab: [:string, { enum: ResourcePage::TABS }],
             download_mode: [:string, { enum: DownloadMode::MODES }],
             can_download: :boolean,
             restriction: [:string, { nullable: true }],
             download: [:number, { nullable: true }],
             updated_on: [:string, { nullable: true }],
             guide_path: [:string, { nullable: true }],
             issue_url: :string
    attributes :tab, :download_mode, :download, :issue_url
    attribute(:can_download) { |page| page[:page].can_download? }
    # Sanitized HTML.
    attribute(:restriction) { |page| page[:page].restriction }
    attribute(:updated_on) { |page| page[:page].updated_on&.strftime(ResourcePage::DATE_FORMAT) }
    attribute(:guide_path) { |page| page[:page].guide_path }

    # Previews.for; null when the resource's type has no preview.
    typelize preview: 'Previews::MushafLayoutResource | Previews::FontResource | Previews::ScriptResource | ' \
                      'Previews::UnavailableResource | null'
    attribute(:preview, inertia: :defer) do |page|
      Previews.as_json(Previews.for(page[:page].resource, page[:preview_query]))
    end
  end
end
