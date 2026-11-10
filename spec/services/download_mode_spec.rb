require 'clone_helper'
require 'open3'

RSpec.describe DownloadMode do
  def with_mode(value)
    original = ENV.fetch('QUL_DOWNLOAD_MODE', nil)
    ENV['QUL_DOWNLOAD_MODE'] = value
    yield
  ensure
    ENV['QUL_DOWNLOAD_MODE'] = original
  end

  it 'defaults to sign_in when the setting is unset or blank' do
    with_mode(nil) { expect(described_class.current).to eq('sign_in') }
    with_mode('') { expect(described_class.current).to eq('sign_in') }
    with_mode(nil) { expect(described_class).not_to be_public }
  end

  it 'reads public' do
    with_mode('public') { expect(described_class).to be_public }
  end

  it 'refuses an unknown value' do
    with_mode('everyone') do
      expect { described_class.current }.to raise_error(DownloadMode::UnknownMode, /QUL_DOWNLOAD_MODE/)
    end
  end

  it 'fails the boot on an unknown value, and boots on a known one' do
    boot = ->(value) { Open3.capture2e({ 'QUL_DOWNLOAD_MODE' => value }, 'bin/rails', 'runner', 'puts :booted') }

    output, status = boot.call('everyone')
    expect(status).not_to be_success
    expect(output).to include('QUL_DOWNLOAD_MODE')
    expect(output).not_to include('booted')

    output, status = boot.call('public')
    expect(status).to be_success, output
    expect(output.lines.last.strip).to eq('booted')
  end
end
