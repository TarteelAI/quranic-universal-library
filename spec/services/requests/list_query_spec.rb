# frozen_string_literal: true

require 'clone_helper'
require_relative '../../support/download_files'

# The public list of resource requests: visible requests with their vote counts, sorted by votes
# or by date, one page per query.
RSpec.describe Requests::ListQuery do
  include DownloadFiles
  include ActiveSupport::Testing::TimeHelpers

  let(:author) { create_account }
  let(:voters) { Array.new(3) { create_account } }

  def create_request(title, created_at:, votes: 0, hidden: false)
    travel_to(created_at) do
      ResourceRequest.create!(title: title, description: 'Spec.', resource_type: 'translation', user: author,
                              hidden: hidden,).tap do |request|
        voters.first(votes).each { |voter| ResourceRequestVote.create!(resource_request: request, user: voter) }
      end
    end
  end

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == 'SCHEMA' || payload[:sql].start_with?('SAVEPOINT') }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    count
  end

  let!(:older) { create_request('Older, two votes', created_at: Time.zone.parse('2026-11-01'), votes: 2) }
  let!(:newer) { create_request('Newer, one vote', created_at: Time.zone.parse('2026-11-10'), votes: 1) }
  let!(:newest) { create_request('Newest, no votes', created_at: Time.zone.parse('2026-11-12')) }
  let!(:hidden) do
    create_request('Hidden, three votes', created_at: Time.zone.parse('2026-11-11'), votes: 3, hidden: true)
  end

  it 'sorts by votes, most first, then newest first, and never returns a hidden request' do
    result = described_class.new(sort: 'votes').call

    expect(result.requests.map(&:title)).to eq(['Older, two votes', 'Newer, one vote', 'Newest, no votes'])
    expect(result.requests.map(&:votes_count)).to eq([2, 1, 0])
    expect(result).to have_attributes(sort: 'votes', page: 1, pages: 1, total: 3)
  end

  it 'sorts by date, newest first' do
    result = described_class.new(sort: 'date').call

    expect(result.requests.map(&:title)).to eq(['Newest, no votes', 'Newer, one vote', 'Older, two votes'])
  end

  it 'sorts by votes when the sort is missing or unknown' do
    expect(described_class.new(sort: nil).call.sort).to eq('votes')
    expect(described_class.new(sort: 'author').call.requests.first).to eq(older)
  end

  it 'says which requests the given user voted for' do
    result = described_class.new(sort: 'votes', user: voters.second).call

    expect(result.requests.to_h { |request| [request.title, request.voted] })
      .to eq('Older, two votes' => true, 'Newer, one vote' => false, 'Newest, no votes' => false)
    expect(described_class.new(sort: 'votes').call.requests.map(&:voted)).to eq([false, false, false])
  end

  it 'reads one page, its vote counts and the total in one query' do
    result = nil
    queries = count_queries do
      result = described_class.new(sort: 'votes', page: 2, per_page: 2, user: voters.first).call
      result.requests.map { |request| [request.title, request.votes_count, request.voted] }
    end

    expect(queries).to eq(1)
    expect(result.requests.map(&:title)).to eq(['Newest, no votes'])
    expect(result).to have_attributes(page: 2, pages: 2, total: 3)
  end

  it 'returns an empty page past the last one' do
    result = described_class.new(sort: 'votes', page: 3, per_page: 2).call

    expect(result.requests).to be_empty
  end

  it 'reads no author or voter of a request' do
    request = described_class.new(sort: 'votes').call.requests.first

    expect(request.attributes.keys).to contain_exactly(
      'id', 'title', 'description', 'resource_type', 'language', 'status', 'created_at', 'votes_count', 'voted',
      'total_count',
    )
  end
end
