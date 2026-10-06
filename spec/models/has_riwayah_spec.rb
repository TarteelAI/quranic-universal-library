# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HasRiwayah do
  let(:hafs) { Riwayah.hafs }
  let(:warsh) { Riwayah.find_by!(slug: 'warsh') }
  let(:mushaf) { Mushaf.find(5) }

  it 'exposes the riwayah under both names' do
    expect(mushaf.riwayah).to eq(hafs)
    expect(mushaf.qirat_type).to eq(hafs)
    expect(mushaf.riwayah_id).to eq(mushaf.qirat_type_id)
  end

  it 'keeps qirat_type_id equal to riwayah_id when riwayah changes' do
    mushaf.update!(riwayah: warsh)
    expect(mushaf.reload.qirat_type_id).to eq(warsh.id)
    expect(mushaf.riwayah_id).to eq(warsh.id)
  end

  it 'keeps riwayah_id equal to qirat_type_id when the legacy column is written' do
    mushaf.update!(qirat_type_id: warsh.id)
    expect(mushaf.reload.riwayah_id).to eq(warsh.id)
    expect(mushaf.riwayah).to eq(warsh)
  end

  it 'assigning through the legacy writer sets both' do
    mushaf.qirat_type = warsh
    mushaf.save!
    expect(mushaf.reload.riwayah_id).to eq(warsh.id)
    expect(mushaf.qirat_type_id).to eq(warsh.id)
  end

  it 'lets a riwayah list its mushafs through riwayah_id' do
    expect(hafs.mushafs).to include(mushaf)
    expect(warsh.mushafs).to be_empty
  end

  it 'applies to recitations and audio recitations' do
    rec = Recitation.new(name: 'spec', reciter_name: 'spec', riwayah: warsh)
    rec.send(:sync_legacy_qirat_type_id)
    expect(rec.qirat_type_id).to eq(warsh.id)

    audio = Audio::Recitation.new(name: 'spec', qirat_type_id: hafs.id)
    audio.send(:sync_legacy_qirat_type_id)
    expect(audio.riwayah_id).to eq(hafs.id)
    expect(audio.qirat_type).to eq(hafs)
  end
end
