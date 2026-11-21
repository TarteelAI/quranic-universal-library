# frozen_string_literal: true

require 'clone_helper'

RSpec.describe DownloadableRelatedResource do
  let(:pair) do
    unlinked = DownloadableResource.where.not(id: described_class.select(:downloadable_resource_id))
    { downloadable_resource_id: unlinked.order(:id).first.id, related_resource_id: DownloadableResource.minimum(:id) }
  end

  it 'refuses a new repeat of a pair, and still saves an existing repeated row' do
    described_class.create!(pair)
    expect { described_class.create!(pair) }.to raise_error(ActiveRecord::RecordInvalid)

    described_class.insert_all!([pair]) # rubocop:disable Rails/SkipsModelValidations -- a repeat the model refuses
    repeats = described_class.where(pair).to_a
    expect(repeats.size).to eq(2)
    expect(repeats.map(&:save)).to eq([true, true])
  end
end
