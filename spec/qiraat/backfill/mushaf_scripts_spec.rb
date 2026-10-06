# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Qiraat::Backfill::MushafScripts do
  let(:mushaf) { Mushaf.find(5) } # KFGQPC Hafs: the slice carries its cached words

  before { mushaf.update_column(:script_id, nil) }

  it 'detects the column a mushaf cache was copied from' do
    report = described_class.new(dry_run: true).call
    expect(report[:assigned][mushaf.id]).to eq('qpc-hafs')
    expect(report[:stale][mushaf.id]).to eq(0)
    expect(mushaf.reload.script_id).to be_nil
  end

  it 'writes script_id and keeps it on later runs unless forced' do
    described_class.new.call
    expect(mushaf.reload.script.slug).to eq('qpc-hafs')
    report = described_class.new.call
    expect(report[:kept][mushaf.id]).to eq('qpc-hafs')
    expect(report[:assigned]).not_to have_key(mushaf.id)
  end

  it 'reports a mushaf whose cache matches no column instead of guessing' do
    MushafWord.where(mushaf_id: mushaf.id).update_all("text = '<span>' || text || '</span>'")
    report = described_class.new.call
    expect(report[:unmatched]).to have_key(mushaf.id)
    expect(mushaf.reload.script_id).to be_nil
  end

  it 'breaks a tie with the font name hint' do
    v2 = Script.find_by!(slug: 'qpc-v2')
    MushafWord.where(mushaf_id: mushaf.id).find_each { |mw| mw.update_column(:text, mw.word.code_v2) if mw.word&.code_v2 }
    mushaf.update_column(:default_font_name, 'v4-tajweed')
    report = described_class.new.call
    expect(report[:assigned][mushaf.id]).to eq('qpc-v4-tajweed')
    mushaf.update_column(:script_id, nil)
    mushaf.update_column(:default_font_name, 'v2')
    expect(described_class.new.call[:assigned][mushaf.id]).to eq(v2.slug)
  end
end
