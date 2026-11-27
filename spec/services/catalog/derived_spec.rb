# frozen_string_literal: true

require 'clone_helper'

# The catalog fields are computed once per catalog change in a process: a request whose
# fingerprint matches the last one uses that computation (Catalog::Derived.latest).
RSpec.describe Catalog::Derived do
  # SQL statements a block sends to either database, without schema and transaction queries.
  def count_queries(&)
    count = 0
    counter = lambda do |*, payload|
      count += 1 unless payload[:cached] || ['SCHEMA', 'TRANSACTION'].include?(payload[:name])
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    count
  end

  def fields(catalog, resource)
    [catalog.of(resource), catalog.summary(resource), catalog.tag_names(resource).sort,
     catalog.superseded_by(resource)&.id,
     catalog.links_from(resource).map { |link| [link.id, link.target.id, link.relation_type] },
     catalog.links_to(resource).map { |link| [link.id, link.source.id, link.relation_type] },]
  end

  before { described_class.latest = nil }

  it 'reuses the computed fields while no row changes, reading only the fingerprint' do
    computed = described_class.new
    resource = computed.resources.find(&:published)

    queries = count_queries { described_class.new.of(resource) }

    expect(queries).to eq(2) # one fingerprint query per database
    expect(described_class.new.of(resource)).to equal(computed.of(resource))
  end

  it 'gives every resource the fields a fresh computation gives' do
    computed = described_class.new
    reused = described_class.new
    expect(reused.instance_variable_get(:@snapshot)).to equal(computed.instance_variable_get(:@snapshot))

    expect(computed.resources.map { |resource| fields(reused, resource) })
      .to eq(computed.resources.map { |resource| fields(computed, resource) })
    expect(computed.resources.sum { |resource| computed.links_from(resource).size }).to be_positive
    expect(computed.resources.map { |resource| computed.tag_names(resource) }).to include(be_present)
  end

  it 'loads only the resources that links name when a caller asks for links, not the catalog' do
    computed = described_class.new
    layout = computed.resources.find { |resource| computed.links_from(resource).any? }
    reused = described_class.new

    expect(reused.links_from(layout).map(&:target).map(&:id)).to eq(computed.links_from(layout).map(&:target).map(&:id))
    expect(reused.instance_variable_get(:@resources)).to be_nil
  end

  it 'computes again inside a transaction that has written, and keeps that computation to itself' do
    computed = described_class.new
    resource = computed.resources.find(&:published)
    resource.update_columns(meta_data: (resource.meta_data || {}).merge('display-name' => 'Derived Spec Name'))

    expect(described_class.fingerprint).to be_nil
    expect(described_class.new.of(resource).display_name).to eq('Derived Spec Name')
    expect(described_class.latest.last).to equal(computed.instance_variable_get(:@snapshot))
  end

  # Committed writes, so the fingerprint is read outside a writing transaction; each example puts
  # the row back.
  describe 'after a committed change' do
    self.use_transactional_tests = false

    it 'computes again when a row changes, also by a write that leaves updated_at alone' do
      resource = DownloadableResource.published.order(:id).first
      meta = resource.meta_data
      before = described_class.fingerprint
      expect(described_class.new.of(resource).display_name).not_to eq('Derived Spec Name')

      begin
        resource.update_columns(meta_data: (meta || {}).merge('display-name' => 'Derived Spec Name'))
        expect(described_class.fingerprint).not_to eq(before)
        expect(described_class.new.of(resource).display_name).to eq('Derived Spec Name')
      ensure
        resource.update_columns(meta_data: meta)
      end
      expect(described_class.new.of(resource).display_name).not_to eq('Derived Spec Name')
    end

    it 'keeps the fingerprint when a download changes only a file counter' do
      file = DownloadableFile.where(published: true).order(:id).first
      counted = file.anonymous_download_count
      before = described_class.fingerprint

      begin
        file.count_download(nil) # an anonymous download
        expect(described_class.fingerprint).to eq(before)
      ensure
        file.update_columns(anonymous_download_count: counted)
      end
    end
  end
end
