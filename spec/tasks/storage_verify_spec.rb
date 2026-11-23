# frozen_string_literal: true

require 'clone_helper'
require 'rake'

# `storage:verify`: every blob row has its object, at its byte size, in its service.
# `storage:fix_sizes`: a row whose size differs takes its object's size and checksum.
RSpec.describe 'storage:verify' do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?('storage:verify') }

  let(:disk) { ActiveStorage::Blob.services.fetch(:test) }

  def blob(key, byte_size, service_name: 'test')
    # Saved without validation: a row on a service that is no longer configured is invalid.
    ActiveStorage::Blob.new(key: key, byte_size: byte_size, service_name: service_name, filename: 'f.txt',
                            content_type: 'text/plain', checksum: 'x', metadata: { analyzed: true },)
      .save!(validate: false)
  end

  def store(key, content)
    disk.upload(key, StringIO.new(content))
  end

  def verify(*services, task: 'storage:verify')
    task = Rake::Task[task]
    task.reenable
    output = StringIO.new
    $stdout = output
    $stderr = StringIO.new
    status = begin
      task.invoke(*services)
      0
    rescue SystemExit => e
      e.status
    ensure
      $stdout = STDOUT
      $stderr = STDERR
    end
    [status, output.string]
  end

  after { ['verify-ok', 'verify-differs'].each { |key| disk.delete(key) } }

  it 'passes when every object is there at its size' do
    store('verify-ok', 'four')
    blob('verify-ok', 4)

    status, output = verify('test')

    expect(status).to eq(0)
    expect(output).to include('test: 1 rows, 1 ok, 0 missing, 0 differ')
  end

  it 'lists missing and differing keys and unconfigured rows, and fails' do
    store('verify-ok', 'four')
    store('verify-differs', 'four')
    blob('verify-ok', 4)
    blob('verify-differs', 5)
    blob('verify-missing', 4)
    blob('verify-elsewhere', 4, service_name: 'retired_service')

    status, output = verify('test', 'retired_service')

    expect(status).to eq(1)
    expect(output).to include('missing test verify-missing',
                              'differs test verify-differs: 4 bytes stored, 5 in the row',
                              'retired_service: not configured, 1 rows not checked',
                              'unconfigured verify-elsewhere',)
    expect(output).to include('test: 3 rows, 1 ok, 1 missing, 1 differ')
    expect(output).not_to include('verify-ok:')
  end

  it 'reports a service it cannot read once, not per row' do
    blob('verify-a', 1, service_name: 'qul_exports')
    blob('verify-b', 1, service_name: 'qul_exports')
    allow(ActiveStorage::Blob.services.fetch(:qul_exports).bucket.client)
      .to receive(:head_object).and_raise(Seahorse::Client::NetworkingError.new(SocketError.new('no host')))

    status, output = verify('qul_exports')

    expect(status).to eq(1)
    expect(output.scan('cannot read the storage').size).to eq(1)
    expect(output).to include('qul_exports: cannot read the storage (Seahorse::Client::NetworkingError: no host)')
  end

  it 'fix_sizes sets a differing row to its object, and leaves missing and matching rows' do
    store('verify-ok', 'four')
    store('verify-differs', 'four')
    blob('verify-ok', 4)
    blob('verify-differs', 5)
    blob('verify-missing', 4)

    status, output = verify('test', task: 'storage:fix_sizes')

    expect(status).to eq(0)
    expect(output).to include('fixed test verify-differs: 5 -> 4 bytes', 'test: 1 rows fixed')
    expect(ActiveStorage::Blob.find_by!(key: 'verify-differs'))
      .to have_attributes(byte_size: 4, checksum: Digest::MD5.base64digest('four'))
    expect(ActiveStorage::Blob.find_by!(key: 'verify-ok').checksum).to eq('x')
    expect(ActiveStorage::Blob.find_by!(key: 'verify-missing').byte_size).to eq(4)
  end
end
