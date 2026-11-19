# frozen_string_literal: true

require 'clone_helper'
require 'active_storage/service/r2_service'

# The storage services of config/storage.yml, read with a given set of settings. Building a
# service and making its links calls no network.
RSpec.describe ActiveStorage::Service::R2Service do
  let(:settings) do
    ['QUL_STORAGE_ACCESS_KEY', 'QUL_STORAGE_ACCESS_KEY_SECRET', 'QUL_STORAGE_BUCKET', 'QUL_STORAGE_ENDPOINT',
     'QUL_STORAGE_REGION', 'QUL_STORAGE_PUBLIC_EXPORT', 'QUL_STORAGE_PUBLIC_HOST', 'QUL_BACKUPS_BUCKET', 'CDN_HOST',]
  end
  let(:r2_style) do
    {
      'QUL_STORAGE_ACCESS_KEY' => 'key-id', 'QUL_STORAGE_ACCESS_KEY_SECRET' => 'key-secret',
      'QUL_STORAGE_BUCKET' => 'public-files', 'QUL_BACKUPS_BUCKET' => 'private-files',
      'QUL_STORAGE_ENDPOINT' => 'https://account.r2.example.test', 'QUL_STORAGE_REGION' => 'auto',
    }
  end

  # config/storage.yml as it reads with only `values` set among the storage settings.
  def configs_with(values)
    original = ENV.to_h.slice(*settings)
    settings.each { |name| ENV.delete(name) }
    ENV.update(values)
    ActiveSupport::ConfigurationFile.parse(Rails.root.join('config', 'storage.yml'))
  ensure
    settings.each { |name| ENV.delete(name) }
    ENV.update(original)
  end

  def blob_url(configs, service_name, key)
    allow(ActiveStorage::Blob).to receive(:services).and_return(ActiveStorage::Service::Registry.new(configs))
    ActiveStorage::Blob.new(key: key, service_name: service_name, filename: 'b.zip',
                            content_type: 'application/zip', byte_size: 1, checksum: 'x',).url
  end

  # What S3Service links for the same service, without the public host.
  def s3_url(configs, service_name, key)
    config = configs.fetch(service_name).except('service', 'public_host').deep_symbolize_keys
    ActiveStorage::Service::S3Service.new(**config)
      .url(key, expires_in: 5.minutes, filename: ActiveStorage::Filename.new('b.zip'),
                disposition: :inline, content_type: 'application/zip',)
  end

  it 'links public files on the public host' do
    configs = configs_with(r2_style.merge('QUL_STORAGE_PUBLIC_HOST' => 'https://files.example.test',
                                          'CDN_HOST' => 'https://cdn.example.test',))

    expect(ActiveStorage::Service::Registry.new(configs).fetch(:qul_exports)).to be_a(described_class)
    expect(blob_url(configs, 'qul_exports', 'qul-exports/a/b.zip'))
      .to eq('https://files.example.test/qul-exports/a/b.zip')
  end

  it 'falls back to CDN_HOST and escapes each path segment' do
    configs = configs_with(r2_style.merge('CDN_HOST' => 'https://cdn.example.test/'))

    expect(blob_url(configs, 'qul_exports', 'qul-exports/a/b c.zip'))
      .to eq('https://cdn.example.test/qul-exports/a/b%20c.zip')
    expect(blob_url(configs, 'qul_exports', 'qul-exports/a/'))
      .to eq('https://cdn.example.test/qul-exports/a/')
  end

  it 'signs private files on the endpoint host, for a day' do
    configs = configs_with(r2_style.merge('QUL_STORAGE_PUBLIC_HOST' => 'https://files.example.test'))

    ['database_backups', 'amazon_s3'].each do |name|
      uri = URI(blob_url(configs, name, 'backups/b.zip'))
      expect(uri.host).to eq('private-files.account.r2.example.test'), name
      expect(uri.path).to eq('/backups/b.zip')
      expect(Rack::Utils.parse_query(uri.query))
        .to include('X-Amz-Expires' => 1.day.to_i.to_s, 'X-Amz-Signature' => be_present)
    end
  end

  it 'links as S3Service does when neither public host is set' do
    configs = configs_with(r2_style)

    expect(blob_url(configs, 'qul_exports', 'qul-exports/a/b.zip'))
      .to eq(s3_url(configs, 'qul_exports', 'qul-exports/a/b.zip'))
      .and eq('https://public-files.account.r2.example.test/qul-exports/a/b.zip')
  end

  it 'builds every service on the fallbacks when nothing is set' do
    configs = configs_with({})

    expect(blob_url(configs, 'qul_exports', 'qul-exports/a/b.zip'))
      .to eq(s3_url(configs, 'qul_exports', 'qul-exports/a/b.zip'))
      .and eq('https://missing.fix.me/qul-exports/a/b.zip')
    expect(URI(blob_url(configs, 'amazon_s3', 'k')).host).to eq('missing.fix.me')
  end

  # R2 refuses an upload that carries the SDK's default checksum beside Rails' Content-MD5.
  it 'adds an SDK checksum only where S3 requires one' do
    registry = ActiveStorage::Service::Registry.new(configs_with(r2_style))

    ['qul_exports', 'amazon_s3', 'database_backups'].each do |name|
      expect(registry.fetch(name).bucket.client.config.request_checksum_calculation).to eq('when_required')
    end
  end
end
