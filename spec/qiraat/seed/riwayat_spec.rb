# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Qiraat::Seed::Riwayat do
  let(:dir) { QiraatFixtures::DIR.join('upstream') }

  # Recreate the legacy qirat_types rows exactly as production had them:
  # eight named rows with no slug, including "Test".
  def seed_legacy!
    Riwayah.delete_all
    %w[Hafs Warsh Sousi Khalaf Qaloun Douri Test Shuba].each_with_index do |name, i|
      Riwayah.insert_all([{ id: i + 1, name: name, created_at: Time.current, updated_at: Time.current }])
    end
    QiraatFixtures.reset_sequence(Riwayah)
  end

  before do
    Qiraat::Seed::Reference.new(dir: dir).call
    seed_legacy!
  end

  it 'keeps the legacy ids and gives them upstream slugs' do
    report = described_class.new(dir: dir).call
    expect(report).to eq(matched: 7, created: 13, deleted: 1)
    expect(Riwayah.count).to eq(20)
    expect(Riwayah.find(1).slug).to eq('hafs')
    expect(Riwayah.find(2).slug).to eq('warsh')
    expect(Riwayah.find(3).slug).to eq('susi')
    expect(Riwayah.find(5).slug).to eq('qalun')
    expect(Riwayah.find(6).slug).to eq('duri')
    expect(Riwayah.find(8).slug).to eq('shuba')
    expect(Riwayah.find_by(id: 7)).to be_nil # "Test"
    expect(Riwayah.find(1).name).to eq('Hafs') # legacy display name untouched
  end

  it 'attaches every rawi to its qiraah and keeps the two Khalafs apart' do
    described_class.new(dir: dir).call
    expect(Riwayah.pluck(:slug)).to match_array(Riwayah::SLUGS)
    expect(Riwayah.find_by(slug: 'hafs').qiraah.slug).to eq('asim')
    expect(Riwayah.find_by(slug: 'warsh').qiraah.slug).to eq('nafi')
    expect(Riwayah.find_by(slug: 'khalaf').qiraah.slug).to eq('hamza')
    expect(Riwayah.find_by(slug: 'ishaq').qiraah.slug).to eq('khalaf')
    expect(Riwayah.where(qiraah: Qiraah.find_by(slug: 'khalaf')).pluck(:slug)).to match_array(%w[ishaq idris])
  end

  it 'flags the legacy Khalaf row as unverified and nothing else' do
    described_class.new(dir: dir).call
    expect(Riwayah.find(4).slug).to eq('khalaf')
    expect(Riwayah.find(4)).to be_unverified
    expect(Riwayah.where("meta_data->>'unverified' = 'true'").count).to eq(1)
  end

  it 'leaves every riwayah disabled' do
    described_class.new(dir: dir).call
    expect(Riwayah.enabled).to be_empty
  end

  it 'is idempotent' do
    described_class.new(dir: dir).call
    ids = Riwayah.order(:id).pluck(:id, :slug)
    described_class.new(dir: dir).call
    expect(Riwayah.order(:id).pluck(:id, :slug)).to eq(ids)
    expect(Riwayah.find(1).name).to eq('Hafs')
  end

  it 'does not delete a legacy row that is still referenced' do
    Mushaf.update_all(riwayah_id: 7)
    described_class.new(dir: dir).call
    expect(Riwayah.find_by(id: 7)&.name).to eq('Test')
  end
end
