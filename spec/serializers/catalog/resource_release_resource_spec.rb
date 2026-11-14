# frozen_string_literal: true

require 'clone_helper'
require_relative '../../support/download_files'

RSpec.describe Catalog::ResourceReleaseResource do
  include DownloadFiles

  let(:resource) { create_download_resource }

  # The content row is a shared clone row, so its export version is stubbed in every case.
  def export_version(value)
    allow(resource.resource_content).to receive(:meta_value).and_call_original
    allow(resource.resource_content).to receive(:meta_value).with('exported-version').and_return(value)
  end

  def serialize
    described_class.new(Catalog::ResourcePage.new(resource, viewer: nil)).as_json.deep_symbolize_keys
  end

  it 'gives the export version and its date where the content row has one' do
    create_download_file(resource)
    export_version('1714953600')

    expect(serialize).to eq(version: '1714953600', updatedOn: '6 May 2024')
  end

  it 'gives no version and the date of the newest file without an export version' do
    export_version(nil)
    create_download_file(resource).file.blob.update_columns(created_at: Time.zone.local(2025, 3, 1, 12))
    create_download_file(resource).file.blob.update_columns(created_at: Time.zone.local(2025, 9, 14, 12))

    expect(serialize).to eq(version: nil, updatedOn: '14 September 2025')
  end

  it 'gives neither without an export version or a file' do
    export_version(nil)
    expect(serialize).to eq(version: nil, updatedOn: nil)
  end
end
