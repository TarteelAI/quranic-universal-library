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
    resources = described_class.new(type: type.key).call
    props = Catalog::TypesShowResource.new(
      { type: type, types: Catalog::Taxonomy.types, resources: resources,
        comparison: Catalog::Comparison.new(type, resources).call }
    ).serializable_hash

    expect(props['type']).to include('key' => 'surah-info', 'title' => 'Surah info',
                                     'category' => { 'key' => 'tafsir', 'label' => 'Tafsir and commentary' })
    expect(props['types'].size).to eq(14)
    expect(props['resources'].first.keys).to contain_exactly(
      'id', 'name', 'type', 'toParam', 'filesCount', 'language', 'granularity', 'status', 'scriptFamily',
      'recommendation', 'supersededBy'
    )
    expect(props['resources']).to all(include('language' => be_present))
  end
end

RSpec.describe Catalog::Taxonomy do
  it 'has one entry for each resource type the CMS knows' do
    expect(described_class.types.map(&:key)).to match_array(DownloadableResource::RESOURCE_TYPES)
  end

  it 'has the statuses and script families of the model, and every granularity of the catalog' do
    expect(described_class.statuses.map(&:key)).to eq(DownloadableResource.statuses.keys)
    expect(described_class.script_families.map(&:key)).to eq(DownloadableResource.script_families.keys)
    expect(described_class.renderings.map(&:key)).to eq(DownloadableResource.renderings.keys)
    expect(described_class.granularities.map(&:key)).to include(*DownloadableResource.distinct.pluck(:cardinality_type))
  end

  it 'names a comparison column only from the column vocabulary' do
    expect(described_class::COMPARISONS.values.flatten).to all(be_in(described_class::COMPARISON_COLUMNS.keys))
    expect(described_class::COMPARISONS.keys + described_class::PICKS.keys).to all(be_in(described_class::TYPES.keys))
  end

  it 'maps file type strings onto the format vocabulary' do
    {
      'json' => 'json', 'simple.json' => 'json', 'translation-with-footnote-tags.json' => 'json',
      'letter-segments-json' => 'json', 'sqlite' => 'sqlite', 'translation-text-chunk.sqlite' => 'sqlite',
      'letter-segments-sqlite' => 'sqlite', 'csv' => 'csv', 'docx' => 'docx', 'ttf' => 'font', 'woff2' => 'font',
      'OTF' => 'font', 'svg' => 'svg', 'images' => 'image', 'Ligatures' => 'other', nil => 'other'
    }.each { |file_type, format| expect(described_class.format_for(file_type)).to eq(format), file_type.inspect }

    keys = described_class.formats.map(&:key)
    formats = DownloadableFile.distinct.pluck(:file_type).map { |type| described_class.format_for(type) }
    expect(formats).to all(be_in(keys))
  end
end
