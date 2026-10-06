# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Qiraat::Seed::Reference do
  subject(:seed) { described_class.new(dir: QiraatFixtures::DIR.join('upstream')) }

  it 'loads the six counting systems and ten qiraat from the pinned files' do
    report = seed.call
    expect(report).to eq(counting_systems: 6, qiraat: 10)
    expect(CountingSystem.pluck(:slug)).to match_array(CountingSystem::SLUGS)
    expect(Qiraah.pluck(:slug)).to match_array(Qiraah::SLUGS)
  end

  it 'marks kufi as the reference system and reads totals from the file, not constants' do
    seed.call
    kufi = CountingSystem.kufi
    expect(kufi.is_reference).to be(true)
    expect(CountingSystem.where(is_reference: true).count).to eq(1)
    expect(kufi.total_ayahs).to eq(QiraatFixtures.counting_systems['kufi']['total_ayahs'])
  end

  it 'attributes each qari to the counting system the file names' do
    seed.call
    expect(Qiraah.find_by(slug: 'asim').counting_system.slug).to eq('kufi')
    expect(Qiraah.find_by(slug: 'nafi').counting_system.slug).to eq('madani-last')
    expect(Qiraah.find_by(slug: 'abu-amr').counting_system.slug).to eq('basri')
    expect(Qiraah.find_by(slug: 'ibn-kathir').counting_system.slug).to eq('makki')
  end

  it 'keeps the two Khalafs apart: the tenth qari is khalaf, Hamza is hamza' do
    seed.call
    expect(Qiraah.find_by(slug: 'khalaf').name_en).to eq('Khalaf al-Ashir')
    expect(Qiraah.find_by(slug: 'hamza').name_en).to eq('Hamza')
  end

  it 'is idempotent' do
    seed.call
    ids = Qiraah.order(:id).pluck(:id)
    seed.call
    expect(Qiraah.order(:id).pluck(:id)).to eq(ids)
    expect(CountingSystem.count).to eq(6)
  end
end
