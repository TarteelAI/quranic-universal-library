require 'clone_helper'
require_relative '../support/catalog_resources'

# The review column's model rule: a drafted value changed outside a backfill is no longer a
# draft, and the backfills leave it as the person set it.
RSpec.describe DownloadableResource do
  before { Catalog::Backfill.run }

  def drafted(resource)
    resource.reload.review.fetch('drafted', {})
  end

  def reviewed(resource)
    resource.reload.review.fetch('reviewed', {})
  end

  def with_draft(field)
    described_class.where("review->'drafted' ? :field", field: field).order(:id).first!
  end

  it 'clears the entry of a drafted field changed through the model, and the next backfill keeps the change' do
    resource = with_draft('script_family')
    other_drafts = drafted(resource).keys - ['script_family']
    changed = resource.script_family == 'other' ? 'madani' : 'other'

    resource.update!(script_family: changed)

    expect(drafted(resource).keys).to match_array(other_drafts)
    expect(reviewed(resource)).to have_key('script_family')

    Catalog::Backfill.run

    expect(resource.reload.script_family).to eq(changed)
    expect(drafted(resource)).not_to have_key('script_family')
  end

  it 'keeps a drafted value a person set back to its default' do
    resource = with_draft('short_summary')

    resource.update!(short_summary: ' ')
    Catalog::Backfill.run

    expect(resource.reload.short_summary).to be_nil
    expect(drafted(resource)).not_to have_key('short_summary')
  end

  it 'treats status and its superseded-by pointer as one decision' do
    resource = described_class.find_by!(status: 'superseded')

    resource.update!(status: 'legacy', superseded_by: nil)
    Catalog::Backfill.run

    expect(resource.reload).to have_attributes(status: 'legacy', superseded_by_id: nil)
    expect(drafted(resource).keys & %w[status superseded_by_id]).to be_empty
    expect(reviewed(resource).keys).to include('status', 'superseded_by_id')
  end

  it 'keeps every entry when a save changes no drafted field, as the CMS form does' do
    resource = with_draft('short_summary')
    entries = drafted(resource)

    resource.update!(name: "#{resource.name} ", short_summary: resource.short_summary, info: resource.info)

    expect(drafted(resource)).to eq(entries)
  end

  it 'clears a drafted link deleted or retyped through the model, and the next backfill does not restore it' do
    layout = resource_named('KFGQPC V4 layout (1441H print)')
    link = layout.downloadable_related_resources.requires.sole
    key = "link:#{link.related_resource_id}"
    expect(drafted(layout)).to have_key(key)

    link.destroy!
    Catalog::Backfill.run

    expect(layout.downloadable_related_resources.where(related_resource_id: link.related_resource_id)).to be_empty
    expect(drafted(layout)).not_to have_key(key)

    retyped = resource_named('KFGQPC V2 layout (1421H print)').downloadable_related_resources.requires.sole
    retyped.update!(relation_type: 'pairs_with')
    Catalog::Backfill.run

    expect(retyped.reload.relation_type).to eq('pairs_with')
    expect(drafted(retyped.downloadable_resource)).not_to have_key("link:#{retyped.related_resource_id}")
  end

  it 'reports, per field, whether the value is reviewed' do
    resource = with_draft('rendering')

    expect(resource.reviewed?(:rendering)).to be(false)
    expect(resource.reviewed?(:recommended)).to be(true)

    resource.mark_reviewed!('rendering')

    expect(resource.reload.reviewed?(:rendering)).to be(true)
  end
end
