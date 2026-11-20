# frozen_string_literal: true

require 'clone_helper'
require_relative '../../support/catalog_resources'

# The catalog fields are computed from the clone's rows when a resource is serialized
# (Catalog::Derived): no column holds them, and no backfill has run.
RSpec.describe Catalog::ResourceResource do
  def serialize(resource)
    described_class.new(resource).as_json.deep_symbolize_keys
  end

  def ref(resource)
    { id: resource.id, name: resource.display_name, type: resource.resource_type, toParam: resource.to_param }
  end

  let(:layout) { resource_named('KFGQPC V2 layout (1421H print)') }
  let(:font) { resource_named('QPC V2 Font') }
  let(:old) { resource_named('Syllables Transliteration(Old)') }
  let(:replacement) { resource_named('Syllables Transliteration') }

  describe 'computed values' do
    it 'makes a name marked (Old) superseded by the one resource with the same name, with a summary' do
      expect(old.short_summary).to be_nil

      expect(serialize(old)).to include(
        id: old.id, name: 'Syllables Transliteration(Old)', type: 'transliteration', toParam: old.to_param,
        status: 'superseded', recommended: false, scriptFamily: nil, rendering: nil,
        summary: 'English transliteration, ayah by ayah. JSON and SQLite files.', supersededBy: ref(replacement),
      )
      expect(serialize(replacement)).to include(status: 'stable', supersededBy: nil)
    end

    it 'makes it legacy when no resource replaces it' do
      expect(serialize(resource_named('Tajweed Images(Old)')))
        .to include(status: 'legacy', supersededBy: nil, rendering: 'image')
    end

    it 'reads script family and rendering from the content rows and the mushaf' do
      expect(serialize(layout)).to include(
        scriptFamily: 'madani', rendering: 'glyph_page',
        summary: 'Mushaf layout with 604 pages and 15 lines on each page. SQLite and DOCX files.',
      )
      expect(serialize(font)).to include(scriptFamily: 'madani', rendering: 'glyph_page')
    end

    it 'tells resources with one name in a type apart by what differs between them' do
      scripts = DownloadableResource.where(resource_type: 'quran-script', name: 'Uthmani').order(:id)

      expect(scripts.map { |script| serialize(script)[:name] })
        .to eq(['Uthmani (Word by word)', 'Uthmani (Ayah by Ayah)'])
    end

    it 'recommends the one layout of a script family whose mushaf is the default, and the font it requires' do
      expect(serialize(layout)).to include(recommended: false)

      MushafLayouts::Page.mushaf_for(layout).update_columns(is_default: true)
      Catalog::Derived.reset

      expect([layout, font].map { |resource| serialize(resource)[:recommended] }).to eq([true, true])
    end

    it 'shows the editor summary when the resource has one' do
      layout.update_columns(short_summary: 'Pages of the 1421H print.')

      expect(serialize(layout)).to include(summary: 'Pages of the 1421H print.')
    end
  end

  describe 'relations' do
    let(:script) { resource_named('QPC V2 Glyph - Word by Word') }

    it 'makes the link from a layout to the font its mushaf names a requires-link, first; other links pair' do
      expect(DownloadableRelatedResource.where(downloadable_resource: layout).pluck(:related_resource_id))
        .to contain_exactly(font.id, script.id)

      expect(serialize(layout)[:relations]).to eq([
        { relationType: 'requires', resource: ref(font) },
        { relationType: 'pairs_with', resource: ref(script) },
      ])
    end

    it 'has the requires-link of a layout whose font no link row names' do
      nastaleeq = resource_named('KFGQPC Nastaleeq 15 lines layout')
      expect(DownloadableRelatedResource.where(downloadable_resource: nastaleeq)).to be_empty

      expect(serialize(nastaleeq)[:relations])
        .to eq([{ relationType: 'requires', resource: ref(resource_named('KFGQPC Nastaleeq')) }])
    end

    it 'skips a link with a missing end and a repeat of a pair, without deleting them' do
      rows = [script.id, script.id, 0].map { |id| { downloadable_resource_id: layout.id, related_resource_id: id } }
      DownloadableRelatedResource.insert_all!(rows) # rubocop:disable Rails/SkipsModelValidations -- rows the model refuses
      Catalog::Derived.reset

      expect(serialize(layout)[:relations].map { |relation| relation[:resource][:id] }).to eq([font.id, script.id])
      expect(DownloadableRelatedResource.where(downloadable_resource: layout).count).to eq(5)
    end

    it 'leaves out relations to unpublished resources' do
      font.update_columns(published: false)
      Catalog::Derived.reset

      expect(serialize(layout)[:relations].map { |relation| relation[:resource][:type] }).to eq(['quran-script'])
    end
  end

  describe 'an override in the meta data' do
    it 'sets the display name' do
      override_catalog(layout, 'display-name' => 'Madinah layout, 1421H')

      expect(serialize(layout)).to include(name: 'Madinah layout, 1421H')
    end

    it 'sets the script family' do
      override_catalog(layout, 'script-family' => 'indopak')

      expect(serialize(layout)).to include(scriptFamily: 'indopak', rendering: 'glyph_page')
    end

    it 'sets the rendering' do
      override_catalog(layout, 'rendering' => 'svg')

      expect(serialize(layout)).to include(rendering: 'svg', scriptFamily: 'madani')
    end

    it 'sets the status, and a stable status takes the replacement away' do
      override_catalog(layout, 'status' => 'beta')
      override_catalog(old, 'status' => 'stable')

      expect(serialize(layout)).to include(status: 'beta')
      expect(serialize(old)).to include(status: 'stable', supersededBy: nil)
    end

    it 'sets the replacement by slug or id, which makes the resource superseded' do
      replacement.update_columns(slug: 'syllables-transliteration')
      override_catalog(layout, 'superseded-by' => font.id)
      override_catalog(resource_named('Tajweed Images(Old)'), 'superseded-by' => 'syllables-transliteration')

      expect(serialize(layout)).to include(status: 'superseded', supersededBy: ref(font))
      expect(serialize(resource_named('Tajweed Images(Old)')))
        .to include(status: 'superseded', supersededBy: ref(replacement.reload))
    end

    it 'sets the recommended flag, and false wins over what the data shows' do
      override_catalog(font, 'recommended' => true)
      expect(serialize(font)).to include(recommended: true)

      MushafLayouts::Page.mushaf_for(layout).update_columns(is_default: true)
      override_catalog(layout, 'recommended' => false)
      override_catalog(font, 'recommended' => nil)

      expect([layout, font].map { |resource| serialize(resource)[:recommended] }).to eq([false, false])
    end

    it 'is ignored when its value is not valid: the computed value shows' do
      computed = [layout, old].map { |resource| serialize(resource) }

      override_catalog(layout, 'script-family' => 'kufi', 'rendering' => 42, 'status' => 'retired',
                               'recommended' => 'maybe', 'display-name' => '  ',)
      override_catalog(old, 'superseded-by' => 'no-such-resource', 'status' => '')

      expect([layout, old].map { |resource| serialize(resource) }).to eq(computed)
    end

    it 'cannot make a resource its own replacement' do
      override_catalog(layout, 'superseded-by' => layout.id)

      expect(serialize(layout)).to include(status: 'stable', supersededBy: nil)
    end
  end
end
