require 'clone_helper'
require_relative '../../support/catalog_resources'

RSpec.describe Catalog::ResourceResource do
  before { Catalog::Backfill.run }

  def serialize(resource)
    described_class.new(resource).as_json.deep_symbolize_keys
  end

  it 'carries status, the recommended flag, script family, rendering and summary, each with its reviewed flag' do
    resource = resource_named('Syllables Transliteration(Old)')
    replacement = resource_named('Syllables Transliteration')

    props = serialize(resource)

    expect(props).to include(
      id: resource.id, name: resource.display_name, type: 'transliteration', toParam: resource.to_param,
      status: 'superseded', recommended: false, scriptFamily: nil, rendering: nil, summary: resource.short_summary,
      supersededBy: { id: replacement.id, name: replacement.display_name, type: 'transliteration',
                      toParam: replacement.to_param }
    )
    expect(props[:summary]).to be_present
    expect(props[:reviewed]).to eq(status: false, supersededBy: false, recommended: true, scriptFamily: true,
                                   rendering: true, summary: false)

    resource.mark_reviewed!

    expect(serialize(resource.reload)[:reviewed].values).to all(be(true))
  end

  it 'reports the superseded-by pointer as not reviewed while the status beside it is drafted' do
    legacy = resource_named('Tajweed Images(Old)')

    expect(serialize(legacy)).to include(status: 'legacy', supersededBy: nil)
    expect(serialize(legacy)[:reviewed]).to include(status: false, supersededBy: false)
  end

  it 'carries typed relations to published resources, requires first, with a reviewed flag per link' do
    layout = resource_named('KFGQPC V2 layout (1421H print)')
    font = resource_named('QPC V2 Font')
    script = resource_named('QPC V2 Glyph - Word by Word')

    relations = serialize(layout)[:relations]

    expect(relations).to eq([
      { relationType: 'requires', reviewed: false,
        resource: { id: font.id, name: font.display_name, type: 'font', toParam: font.to_param } },
      { relationType: 'pairs_with', reviewed: true,
        resource: { id: script.id, name: script.display_name, type: 'quran-script', toParam: script.to_param } }
    ])
  end

  it 'leaves out relations to unpublished resources' do
    layout = resource_named('KFGQPC V2 layout (1421H print)')
    resource_named('QPC V2 Font').update_columns(published: false)

    expect(serialize(layout)[:relations].map { |relation| relation[:resource][:type] }).to eq(['quran-script'])
  end
end
