# frozen_string_literal: true

require 'rails_helper'

# P1.3 added riwayah_id beside qirat_type_id; P7.5 dropped the legacy column,
# the QiratType alias and the qirat_type readers.
RSpec.describe HasRiwayah do
  let(:hafs) { Riwayah.hafs }
  let(:warsh) { Riwayah.find_by!(slug: 'warsh') }
  let(:mushaf) { Mushaf.find(5) }

  it 'exposes the riwayah through riwayah_id only' do
    expect(mushaf.riwayah).to eq(hafs)
    expect(mushaf).not_to respond_to(:qirat_type)
    expect(Mushaf.column_names).not_to include('qirat_type_id')
    expect(Recitation.column_names).not_to include('qirat_type_id')
    expect(Audio::Recitation.column_names).not_to include('qirat_type_id')
    expect(defined?(QiratType)).to be_nil
  end

  it 'changes the riwayah' do
    mushaf.update!(riwayah: warsh)
    expect(mushaf.reload.riwayah_id).to eq(warsh.id)
  end

  it 'lets a riwayah list its mushafs through riwayah_id' do
    expect(hafs.mushafs).to include(mushaf)
    expect(warsh.mushafs).to be_empty
  end

  it 'applies to recitations and audio recitations' do
    expect(Recitation.new(riwayah: warsh).riwayah).to eq(warsh)
    expect(Audio::Recitation.new(riwayah_id: hafs.id).riwayah).to eq(hafs)
    expect(Recitation.riwayah_ransackable_associations).to eq(%w[riwayah])
  end
end
