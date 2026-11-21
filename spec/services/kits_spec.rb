# frozen_string_literal: true

require 'clone_helper'

# The kits file (config/kits.yml), read through Kits. Its items are named by hand, so this spec
# is what catches a resource that is renamed or unpublished after a kit names it.
#
# The test clone has the migrations but no catalog backfill, which gives every resource its slug,
# so each example runs it first (in the example's transaction), as production will have.
RSpec.describe Kits do
  before { Catalog::Backfill.run }

  it 'names a published resource by its slug for every item and alternative' do
    slugs = described_class.slugs
    published = DownloadableResource.published.where(slug: slugs).pluck(:slug)

    expect(slugs).not_to be_empty
    expect(slugs - published).to eq([])
  end

  it 'gives each kit a unique key, items with a reason, and answers the guided setup reads in full' do
    kits = described_class.all
    languages = GuidedSetup.languages.map(&:key)

    expect(kits.map(&:key).uniq).to eq(kits.map(&:key))
    kits.each do |kit|
      expect(kit.key).to match(/\A[a-z]+(-[a-z]+)*\z/)
      expect([kit.title, kit.tag, kit.blurb, kit.description]).to all(be_present)
      expect(kit.items).to all(have_attributes(need: be_present, why: be_present))
      expect(GuidedSetup::Answers.from(kit.answers, languages:).answered).to eq(GuidedSetup::STEPS), kit.key
    end
  end

  it 'finds a kit by its key' do
    kit = described_class.all.first

    expect(described_class.find(kit.key)).to eq(kit)
    expect(described_class.find('no-such-kit')).to be_nil
  end

  describe '.resolve' do
    let(:kit) { described_class.all.find { |entry| entry.items.any?(&:alternative) } }
    let(:item) { kit.items.find(&:alternative) }

    def published
      DownloadableResource.published.where(slug: kit.items.flat_map { |entry| [entry.resource, entry.alternative] })
        .index_by(&:slug)
    end

    it 'pairs each item with its resource and its alternative' do
      entries = described_class.resolve(kit, published)

      expect(entries.map { |entry| entry.resource.slug }).to eq(kit.items.map(&:resource))
      expect(entries.find { |entry| entry.item == item }.alternative.slug).to eq(item.alternative)
    end

    it 'leaves out an item whose resource is unpublished, and an unpublished alternative' do
      DownloadableResource.where(slug: item.resource).update_all(published: false)
      other = kit.items.find { |entry| entry != item && entry.alternative }
      DownloadableResource.where(slug: other.alternative).update_all(published: false) if other

      entries = described_class.resolve(kit, published)

      expect(entries.map(&:item)).to eq(kit.items - [item])
      expect(entries.find { |entry| entry.item == other }.alternative).to be_nil if other
    end
  end
end
