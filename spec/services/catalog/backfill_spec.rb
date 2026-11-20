# frozen_string_literal: true

require 'clone_helper'

# Runs the slug backfill on the test clone, which has resources without a slug.
RSpec.describe Catalog::Backfill do
  def value(sql)
    ApplicationRecord.connection.select_value(sql)
  end

  def checksum(table, columns)
    value("SELECT md5(string_agg(#{columns}::text, '|' ORDER BY id)) FROM #{table}")
  end

  it 'gives every resource a unique slug that is not all digits and keeps the slugs that existed' do
    existing = DownloadableResource.where("btrim(slug) <> ''").pluck(:id, :slug).to_h
    expect(existing).not_to be_empty
    expect(DownloadableResource.where(slug: [nil, ''])).not_to be_empty

    described_class.run

    expect(value("SELECT count(*) FROM downloadable_resources WHERE slug IS NULL OR btrim(slug) = ''")).to eq(0)
    expect(value('SELECT count(*) - count(DISTINCT slug) FROM downloadable_resources')).to eq(0)
    expect(value("SELECT count(*) FROM downloadable_resources WHERE slug ~ '^[0-9]+$'")).to eq(0)
    expect(DownloadableResource.where(id: existing.keys).pluck(:id, :slug).to_h).to eq(existing)
  end

  it 'builds a new slug from the display name, so resources with one name get different slugs' do
    scripts = DownloadableResource.where(resource_type: 'quran-script', name: 'Uthmani').order(:id)
    expect(scripts.pluck(:cardinality_type, :slug)).to eq([['1_word', nil], ['1_ayah', nil]])

    described_class.run

    expect(scripts.reload.map(&:display_name)).to eq(['Uthmani (Word by word)', 'Uthmani (Ayah by Ayah)'])
    expect(scripts.pluck(:slug)).to eq(['uthmani-word-by-word', 'uthmani-ayah-by-ayah'])
  end

  it 'writes nothing but slugs: no name, link or tagging changes, and no row is deleted' do
    tables = { 'downloadable_resources' => "id || ':' || coalesce(name, '') || coalesce(meta_data::text, '')",
               'downloadable_related_resources' => 'id', 'downloadable_resource_taggings' => 'id', }
    before = tables.to_h { |table, columns| [table, checksum(table, columns)] }

    described_class.run

    expect(tables.to_h { |table, columns| [table, checksum(table, columns)] }).to eq(before)
  end

  it 'changes rows on the first run and none on the second' do
    first = described_class.run
    second = described_class.run

    expect(first.keys).to eq(['blank_slugs', 'slugs'])
    expect(first.values).to all(be_positive)
    expect(second.values).to all(eq(0))
  end
end
