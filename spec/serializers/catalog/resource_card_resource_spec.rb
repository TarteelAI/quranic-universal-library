# frozen_string_literal: true

require 'clone_helper'
require_relative '../../support/catalog_resources'

# A resource card as the type pages send it. It is built from a resource alone, with no
# controller, request or session, so the public API can reuse it.
RSpec.describe Catalog::ResourceCardResource do
  def card(resource)
    described_class.new(resource).as_json.deep_symbolize_keys
  end

  it 'carries the summary, the status and the formats of the published files, in vocabulary order' do
    resource = resource_named('KFGQPC V2 layout (1421H print)')
    resource.update_columns(short_summary: 'Pages of the 1421H print.', status: 'beta')
    published = resource.downloadable_files.where(published: true).pluck(:file_type)
    expect(published).to be_present

    props = card(resource.reload)

    expect(props).to include(summary: 'Pages of the 1421H print.', status: 'beta', previewKind: 'layout')
    keys = Catalog::Taxonomy.formats.map(&:key)
    expect(props[:formats]).to eq(keys & published.map { |type| Catalog::Taxonomy.format_for(type) })
    expect(props.keys).not_to include(:filesCount)
  end

  it 'leaves out the formats of unpublished files and sends no summary when there is none' do
    resource = resource_named('KFGQPC V2 layout (1421H print)')
    resource.update_columns(short_summary: nil)
    resource.downloadable_files.update_all(published: false)

    expect(card(resource.reload)).to include(summary: nil, formats: [])
  end

  it 'names the card preview of each type, and none for the record types' do
    kinds = Catalog::Taxonomy.types.to_h do |type|
      resource = DownloadableResource.published.find_by(resource_type: type.key)
      [type.key, resource && card(resource)[:previewKind]]
    end

    expect(kinds).to eq(
      'recitation' => 'recitation', 'mushaf-layout' => 'layout', 'quran-script' => 'script', 'font' => 'font',
      'translation' => 'text', 'transliteration' => 'text', 'tafsir' => 'text', 'surah-info' => nil,
      'morphology' => nil, 'mutashabihat' => nil, 'similar-ayah' => nil, 'ayah-topics' => nil,
      'ayah-theme' => nil, 'quran-metadata' => nil,
    )
  end
end
