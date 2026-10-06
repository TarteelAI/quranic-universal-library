# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Qiraat::Seed::Scripts do
  before { Script.delete_all }

  it 'registers every Hafs text column, glyph column and image set exactly once' do
    report = described_class.new.call
    expect(report[:created]).to eq(described_class::HAFS_COLUMN_SCRIPTS.size)
    expect(Script.count).to eq(22)
    expect(Script.pluck(:riwayah_id).uniq).to eq([Riwayah.hafs.id])
    expect(Script.where(storage: 'column').count).to eq(Script.count)

    text_columns = Word.column_names.grep(/\Atext_/)
    text_columns.each { |col| expect(Script.where(column_name: col).count).to eq(1), "#{col} should be named by exactly one script" }
    expect(Script.where(column_name: 'code_v1').count).to eq(1)
    expect(Script.where(column_name: 'code_v2').count).to eq(2) # v2 and the v4 tajweed alias
  end

  it 'keeps the CSS classes the helpers use today' do
    described_class.new.call
    expect(Script.find_by!(slug: 'qpc-hafs').font_css_class).to eq('qpc-hafs')
    expect(Script.find_by!(slug: 'uthmani').font_css_class).to eq('me_quran')
    expect(Script.find_by!(slug: 'digitalkhatt').font_css_class).to eq('digitalkhatt-v2')
    expect(Script.find_by!(slug: 'uthmani-tajweed').font_css_class).to eq('tajweed-new qpc-hafs')
  end

  it 'resolves per-page glyph fonts from the word' do
    described_class.new.call
    word = Word.unscoped.find_by!(location: '1:1:1')
    expect(Script.find_by!(slug: 'qpc-v1').css_class_for(word)).to eq("p#{word.page_number}-v1")
    expect(Script.find_by!(slug: 'qpc-v2').css_class_for(word)).to eq("p#{word.v2_page}-v2")
    expect(Script.find_by!(slug: 'qpc-v4-tajweed').css_class_for(word)).to eq("p#{word.v2_page}-v4-tajweed")
    expect(Script.find_by!(slug: 'qpc-hafs').css_class_for(word)).to eq('qpc-hafs')
  end

  it 'is idempotent' do
    described_class.new.call
    ids = Script.order(:id).pluck(:id, :slug)
    report = described_class.new.call
    expect(report[:created]).to eq(0)
    expect(Script.order(:id).pluck(:id, :slug)).to eq(ids)
  end
end
