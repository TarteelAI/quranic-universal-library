# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('lib/qiraat/gloss_override').to_s

# P6.3: the review queue on /cms/word_differences. The slice's differences
# file plus the dotting variant of word-index.csv (1:4:1 مَٰلِكِ / مَلِكِ) are
# imported; a WBW resource with a shared gloss is created here (none in the
# slice).
RSpec.describe 'CMS word differences review queue (P6.3)', type: :request do
  let(:warsh) { Riwayah.find_by!(slug: 'warsh') }
  let(:qalun) { Riwayah.find_by!(slug: 'qalun') }
  let(:hafs) { Riwayah.hafs }
  let(:word) { Word.find_by!(location: '1:4:1') }
  let(:difference) { WordDifference.find(word.id) }
  let(:rc) { ResourceContent.create!(name: 'spec wbw', sub_type: ResourceContent::SubType::Translation, cardinality_type: ResourceContent::CardinalityType::OneWord, resource_type: 'Word', language_name: 'english', approved: true) }

  before do
    sign_in_admin
    WordDifference.delete_all
    Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call
    Qiraat::Import::WordDifferences.new(path: QiraatFixtures.upstream('differences.json'), word_index_path: QiraatFixtures.upstream('word-index.csv')).call
    WordTranslation.new(resource_content_id: rc.id, word_id: word.id, language_id: 38, language_name: 'english', text: 'Master').save!(validate: false)
  end

  it 'lists 1:4:1 as a dotting variant in the queue with its three spellings' do
    expect(difference.status).to eq('dotting_variant')
    expect(difference.spelling_groups.map { |_t, s| s.sort }).to eq([%w[hafs shuba], %w[bazzi duri qalun warsh], ['susi']])
    expect(difference).to be_meaning_may_differ
    get '/cms/word_differences?scope=needs_review'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('1:4:1').and match(/needs decision/i)
  end

  it 'shows the shared gloss and one override form per spelling group' do
    get "/cms/word_differences/#{word.id}"
    expect(response).to have_http_status(:ok)
    body = response.body
    expect(body).to include('Master')
    expect(body).to include('Apply to shuba') # the Hafs spelling group: only Shuba can carry an override
    expect(body).to include('Apply to bazzi, duri, qalun, warsh').or include('Apply to bazzi, qalun, warsh, duri')
    expect(body).to include("gloss-group-#{rc.id}-2")
  end

  it 'writes one override per riwayah of the group; Warsh reads it, Hafs keeps the shared gloss' do
    group = difference.spelling_groups.index { |_t, s| s.include?('warsh') }
    post "/cms/word_differences/#{word.id}/override", params: { resource_content_id: rc.id, group: group, text: 'King' }
    expect(response).to redirect_to(%r{/cms/word_differences/#{word.id}})
    rows = WordTranslation.overrides.where(word_id: word.id, resource_content_id: rc.id)
    expect(rows.map { |r| r.riwayah.slug }.sort).to eq(%w[bazzi duri qalun warsh])
    expect(rows.map(&:text).uniq).to eq(['King'])
    expect(WordTranslation.for_riwayah(warsh).find_by(word_id: word.id, resource_content_id: rc.id).text).to eq('King')
    expect(WordTranslation.for_riwayah(hafs).find_by(word_id: word.id, resource_content_id: rc.id).text).to eq('Master')
    expect(WordTranslation.shared.where(word_id: word.id).count).to eq(1)
    expect(difference.reload.decision).to eq('overridden')
    expect(difference.review['by']).to be_present

    # applying again updates the same rows
    post "/cms/word_differences/#{word.id}/override", params: { resource_content_id: rc.id, group: group, text: 'Sovereign' }
    expect(WordTranslation.overrides.where(word_id: word.id).count).to eq(4)
    expect(WordTranslation.for_riwayah(qalun).find_by(word_id: word.id).text).to eq('Sovereign')
  end

  it 'removes one override and falls back to the queue when none is left' do
    Qiraat::GlossOverride.new(difference, rc).apply(group: 2, text: 'King', by: 'spec')
    susi = WordTranslation.overrides.find_by!(word_id: word.id, riwayah: Riwayah.find_by!(slug: 'susi'))
    delete "/cms/word_differences/#{word.id}/remove_override", params: { resource_content_id: rc.id, riwayah_id: susi.riwayah_id }
    expect(response).to have_http_status(:redirect)
    expect(WordTranslation.overrides.where(word_id: word.id)).to be_empty
    expect(difference.reload.decision).to be_nil
  end

  it 'records a same-meaning decision with a note' do
    put "/cms/word_differences/#{word.id}/decide", params: { decision: 'same_meaning', note: 'dagger alif only' }
    expect(difference.reload.decision).to eq('same_meaning')
    expect(difference.review['note']).to eq('dagger alif only')
    expect(WordDifference.decided).to include(difference)
    expect(WordDifference.needs_review).not_to include(difference)
    expect { put "/cms/word_differences/#{word.id}/decide", params: { decision: 'nonsense' } }.not_to raise_error
    expect(difference.reload.decision).to eq('same_meaning')
  end
end
