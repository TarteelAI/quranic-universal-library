require 'clone_helper'
require_relative '../../support/catalog_resources'

# The drafting backfills (Catalog::Inference applied by Catalog::Backfill) on the test clone,
# which has no drafted value yet.
RSpec.describe 'Catalog drafted values' do
  def drafted(resource)
    resource.reload.review.fetch('drafted', {})
  end

  def field_values
    DownloadableResource.pluck(:id, *CatalogFields::DRAFTED_FIELDS).to_h do |id, *values|
      [id, CatalogFields::DRAFTED_FIELDS.zip(values).to_h]
    end
  end

  def link_types
    DownloadableRelatedResource.pluck(:downloadable_resource_id, :related_resource_id, :relation_type)
                               .to_h { |source, target, type| [[source, target], type] }
  end

  it 'records every value it wrote in the review column, and nothing else' do
    fields_before = field_values
    links_before = link_types

    Catalog::Backfill.run

    written = field_values.flat_map do |id, values|
      values.filter_map { |field, value| [id, field, value] if value != fields_before[id][field] }
    end
    written += link_types.filter_map do |(source, target), type|
      [source, "link:#{target}", type] if type != links_before[[source, target]]
    end
    entries = DownloadableResource.where.not(review: {}).flat_map do |resource|
      resource.review.fetch('drafted', {}).map { |key, entry| [resource.id, key, entry['value']] }
    end

    expect(written.size).to be > 100
    expect(entries).to match_array(written)
    recorded = DownloadableResource.where.not(review: {}).flat_map { |resource| resource.review['drafted'].values }
    expect(recorded).to all(include('by' => be_present, 'at' => be_present))
  end

  it 'drafts statuses, script families, renderings, requires-links and summaries from the data' do
    Catalog::Backfill.run

    old = resource_named('Syllables Transliteration(Old)')
    replacement = resource_named('Syllables Transliteration')
    expect(old).to have_attributes(status: 'superseded', superseded_by_id: replacement.id)
    expect(drafted(old).keys).to include('status', 'superseded_by_id')
    expect(resource_named('Tajweed Images(Old)')).to have_attributes(status: 'legacy',
                                                                                          superseded_by_id: nil)

    v2_layout = resource_named('KFGQPC V2 layout (1421H print)')
    v2_font = resource_named('QPC V2 Font')
    expect(v2_layout).to have_attributes(script_family: 'madani', rendering: 'glyph_page')
    expect(v2_layout.downloadable_related_resources.find_by!(related_resource: v2_font).relation_type).to eq('requires')
    expect(drafted(v2_layout)["link:#{v2_font.id}"]).to include('value' => 'requires', 'replaced' => 'pairs_with')

    indopak = resource_named('Indopak 15 lines layout(Qudratullah)')
    expect(indopak).to have_attributes(script_family: 'indopak', rendering: 'unicode_font')

    other_types = DownloadableResource.where.not(resource_type: Catalog::Inference::SCRIPT_TYPES)
    expect(other_types.where.not(script_family: nil).or(other_types.where.not(rendering: nil))).to be_empty

    summarised = DownloadableResource.where(resource_type: 'translation').where("review->'drafted' ? 'short_summary'")
    expect(summarised.count).to be > 100
    expect(summarised.pluck(:short_summary)).to all(match(/\A[A-Z].{10,158}\.\z/))
    kept = DownloadableResource.where.not(short_summary: [nil, ''])
                               .where.not("coalesce(review->'drafted', '{}') ? 'short_summary'")
    expect(kept.count).to eq(1)
  end

  def check_recommended_evidence
    recommended = DownloadableResource.where("review->'drafted' ? 'recommended'").to_a
    expect(recommended).to all(have_attributes(recommended: true, published: true))
    expect(recommended.map(&:status)).to all(satisfy { |status| %w[stable beta].include?(status) })

    layouts, fonts = recommended.partition { |resource| resource.resource_type == 'mushaf-layout' }
    expect(fonts.map(&:resource_type)).to all(eq('font'))
    layouts.each do |layout|
      expect(layout.script_family).to be_present
      expect(MushafLayouts::Page.mushaf_for(layout).is_default).to be(true)
    end
    expect(layouts.group_by(&:script_family).values.map(&:size)).to all(eq(1))

    families = fonts.map do |font|
      requiring = layouts.select do |layout|
        layout.downloadable_related_resources.requires.exists?(related_resource: font)
      end
      expect(requiring.size).to eq(1)
      requiring.first.script_family
    end
    expect(families.tally.values).to all(eq(1))
    recommended
  end

  it 'recommends no layout on the clone, where neither default mushaf has a published layout' do
    defaults = Mushaf.where(is_default: true).pluck(:resource_content_id)
    published_layouts = DownloadableResource.published.where(resource_type: 'mushaf-layout')
    expect(published_layouts.where(resource_content_id: defaults)).to be_empty

    Catalog::Backfill.run

    expect(check_recommended_evidence).to be_empty
  end

  it 'recommends the one published layout on a default mushaf, with the font it requires' do
    layout = DownloadableResource.where(resource_type: 'mushaf-layout', published: false)
                                 .find { |resource| MushafLayouts::Page.mushaf_for(resource)&.is_default }
    expect(layout).to be_present
    layout.update_columns(published: true)

    Catalog::Backfill.run

    recommended = check_recommended_evidence
    font = layout.downloadable_related_resources.requires.sole.related_resource
    expect(recommended).to contain_exactly(layout, font)

    # Accepting one of the pair keeps the other drafted, and both stay recommended.
    layout.mark_reviewed!('recommended')
    expect(Catalog::Backfill.run.values.sum).to eq(0)
    expect([layout.reload.recommended, font.reload.recommended]).to eq([true, true])
    expect(drafted(font)).to have_key('recommended')

    # Rejecting the layout takes the font's draft back as well.
    layout.update!(recommended: false)
    Catalog::Backfill.run
    expect([layout.reload.recommended, font.reload.recommended]).to eq([false, false])
    expect(drafted(font)).not_to have_key('recommended')
    expect(Catalog::Backfill.run.values.sum).to eq(0)
  end

  it 'leaves a value a person set' do
    layout = resource_named('KFGQPC V2 layout (1421H print)')
    layout.update!(script_family: 'other')

    Catalog::Backfill.run

    expect(layout.reload.script_family).to eq('other')
    expect(drafted(layout)).not_to have_key('script_family')
  end
end
