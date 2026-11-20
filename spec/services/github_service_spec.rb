# frozen_string_literal: true

require 'clone_helper'

RSpec.describe GithubService do
  # The test environment caches nothing; these examples need a cache.
  around do |example|
    cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = cache
  end

  def answer(response)
    http = instance_double(Net::HTTP, :use_ssl= => true, :open_timeout= => 2, :read_timeout= => 3, :max_retries= => 0)
    allow(http).to receive(:request).and_return(response)
    allow(Net::HTTP).to receive(:new).and_return(http)
    http
  end

  it 'lists the contributors without the bots, and asks GitHub once' do
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    allow(response).to receive(:body).and_return([
      { login: 'someone', type: 'User', contributions: 3 }, { login: 'a-bot', type: 'Bot', contributions: 9 },
    ].to_json)
    http = answer(response)

    2.times { expect(described_class.fetch_contributors(limit: 100).pluck(:login)).to eq(['someone']) }
    expect(described_class.contributors_count).to eq(1)
    expect(http).to have_received(:request).once
  end

  it 'remembers a refused request, and counts the fallback' do
    http = answer(Net::HTTPForbidden.new('1.1', '403', 'rate limit exceeded'))

    2.times { expect(described_class.fetch_contributors(limit: 100)).to eq([]) }
    expect(described_class.contributors_count).to eq(described_class::FALLBACK_CONTRIBUTORS)
    expect(http).to have_received(:request).once
  end

  it 'remembers a request that timed out' do
    allow(Net::HTTP).to receive(:new).and_raise(Net::OpenTimeout)

    2.times { expect(described_class.fetch_contributors(limit: 20)).to eq([]) }
    expect(Net::HTTP).to have_received(:new).once
  end
end
