require 'clone_helper'

RSpec.describe DownloadableResource do
  let(:free_contents) { ResourceContent.where.not(id: described_class.pluck(:resource_content_id)) }

  def create_resource(name, content, **attributes)
    described_class.create!(name: name, resource_type: 'font', cardinality_type: 'quran',
                            resource_content: content, **attributes)
  end

  it 'gets a slug from its name when created without one' do
    resource = create_resource('Catalog Spec Naskh', free_contents.first)

    expect(resource.slug).to eq('catalog-spec-naskh')
  end

  it 'gets a valid slug when its name would give an all-digit slug' do
    resource = create_resource('1405', free_contents.first)

    expect(resource.slug).to eq('1405-font')
  end

  it 'gets a distinct slug when its name would give a taken slug' do
    first, second, third = free_contents.first(3)
    taken = create_resource('Catalog Spec Taken', first, slug: 'catalog-spec-taken').slug
    typed = create_resource('Catalog Spec Taken', second)
    counted = create_resource('Catalog Spec Taken', third)

    expect([taken, typed.slug, counted.slug]).to eq(%w[catalog-spec-taken catalog-spec-taken-font catalog-spec-taken-font-2])
  end

  it 'treats a blank slug as none and refuses an all-digit slug' do
    expect(create_resource('Catalog Spec Blank', free_contents.first, slug: '  ').slug).to eq('catalog-spec-blank')

    resource = described_class.new(name: 'Catalog Spec Digits', slug: '123')
    expect(resource).not_to be_valid
    expect(resource.errors[:slug]).to include('cannot be all digits')
  end

  it 'starts stable, not recommended, with no script family, rendering or display name of its own' do
    resource = create_resource('Catalog Spec Defaults', free_contents.first)

    expect(resource).to have_attributes(status: 'stable', recommended: false, script_family: nil, rendering: nil,
                                        display_name: 'Catalog Spec Defaults', review: {})
  end
end
