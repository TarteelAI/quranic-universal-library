require 'clone_helper'

# The catalog query object and serializers run without a controller, request or session, so the
# public API (next sprint) can reuse them.
RSpec.describe Catalog::ResourcesQuery do
  it 'returns the published resources of one type, by name, with languages preloaded in separate queries' do
    resources = described_class.new(type: 'tafsir').call

    expect(resources.map(&:id)).to match_array(DownloadableResource.published.where(resource_type: 'tafsir').ids)
    expect(resources.map { |r| r.name.downcase }).to eq(resources.map { |r| r.name.downcase }.sort)
    expect(resources).to all(satisfy { |r| r.association(:language).loaded? && r.association(:resource_content).loaded? })
  end

  it 'returns every published resource without a type' do
    expect(described_class.new.call.size).to eq(DownloadableResource.published.count)
  end

  it 'serializes a type page without a controller or request' do
    type = Catalog::Taxonomy.type('surah-info')
    props = Catalog::TypesShowResource.new(
      { type: type, types: Catalog::Taxonomy.types, resources: described_class.new(type: type.key).call }
    ).serializable_hash

    expect(props['type']).to include('key' => 'surah-info', 'title' => 'Surah info',
                                     'category' => { 'key' => 'tafsir', 'label' => 'Tafsir and commentary' })
    expect(props['types'].size).to eq(14)
    expect(props['resources'].first.keys).to contain_exactly(
      'id', 'name', 'type', 'toParam', 'filesCount', 'language', 'granularity'
    )
    expect(props['resources']).to all(include('language' => be_present))
  end
end

RSpec.describe Catalog::Taxonomy do
  it 'has one entry for each resource type the CMS knows' do
    expect(described_class.types.map(&:key)).to match_array(DownloadableResource::RESOURCE_TYPES)
  end
end
