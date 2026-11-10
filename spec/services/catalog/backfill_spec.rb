require 'clone_helper'

# Runs every catalog backfill on the test clone, which has the migrations but no backfill yet.
RSpec.describe Catalog::Backfill do
  def value(sql)
    ApplicationRecord.connection.select_value(sql)
  end

  def name_checksum
    value("SELECT md5(string_agg(id || ':' || coalesce(name, ''), '|' ORDER BY id)) FROM downloadable_resources")
  end

  it 'gives every resource a unique slug that is not all digits and keeps the slugs that existed' do
    existing = DownloadableResource.where("btrim(slug) <> ''").pluck(:id, :slug).to_h
    expect(existing).not_to be_empty

    described_class.run

    expect(value("SELECT count(*) FROM downloadable_resources WHERE slug IS NULL OR btrim(slug) = ''")).to eq(0)
    expect(value('SELECT count(*) - count(DISTINCT slug) FROM downloadable_resources')).to eq(0)
    expect(value("SELECT count(*) FROM downloadable_resources WHERE slug ~ '^[0-9]+$'")).to eq(0)
    expect(DownloadableResource.where(id: existing.keys).pluck(:id, :slug).to_h).to eq(existing)
  end

  it 'tells published resources apart by display name inside each type and leaves name alone' do
    before = name_checksum

    described_class.run

    repeated = value(<<~SQL)
      SELECT count(*) FROM (
        SELECT resource_type, lower(coalesce(nullif(display_name, ''), name)) FROM downloadable_resources
        WHERE published GROUP BY 1, 2 HAVING count(*) > 1
      ) repeated
    SQL
    expect(repeated).to eq(0)
    expect(name_checksum).to eq(before)
  end

  it 'leaves no duplicate or orphaned related link, every undrafted link pairs_with, and no orphaned tagging' do
    described_class.run

    expect(value(<<~SQL)).to eq(0)
      SELECT count(*) FROM (
        SELECT 1 FROM downloadable_related_resources
        GROUP BY downloadable_resource_id, related_resource_id HAVING count(*) > 1
      ) duplicates
    SQL
    expect(value(<<~SQL)).to eq(0)
      SELECT count(*) FROM downloadable_related_resources link
      WHERE NOT EXISTS (SELECT 1 FROM downloadable_resources r WHERE r.id = link.downloadable_resource_id)
         OR NOT EXISTS (SELECT 1 FROM downloadable_resources r WHERE r.id = link.related_resource_id)
    SQL
    expect(value(<<~SQL)).to eq(0)
      SELECT count(*) FROM downloadable_related_resources link
      JOIN downloadable_resources source ON source.id = link.downloadable_resource_id
      WHERE link.relation_type <> 'pairs_with'
        AND NOT coalesce(source.review->'drafted', '{}') ? ('link:' || link.related_resource_id)
    SQL
    expect(value(<<~SQL)).to eq(0)
      SELECT count(*) FROM downloadable_resource_taggings tagging
      WHERE NOT EXISTS (SELECT 1 FROM downloadable_resources r WHERE r.id = tagging.downloadable_resource_id)
    SQL
  end

  it 'changes rows on the first run and none on the second' do
    first = described_class.run
    second = described_class.run

    expect(first.keys).to eq(%w[blank_slugs display_names slugs related_links taggings script_families renderings
                                statuses requires_links recommended summaries])
    # No layout on the clone has the evidence the recommended flag needs (drafts_spec.rb).
    expect(first.except('recommended').values).to all(be_positive)
    expect(second.values).to all(eq(0))
  end
end
