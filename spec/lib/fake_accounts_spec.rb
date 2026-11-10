require 'clone_helper'

RSpec.describe FakeAccounts do
  describe '.check!' do
    it 'refuses in production' do
      production = ActiveSupport::EnvironmentInquirer.new('production')

      expect { described_class.check!(env: production) }
        .to raise_error(FakeAccounts::Refused, /never created in production/)
    end

    it 'refuses when the connected database is not a snapshot clone' do
      allow(SnapshotClone).to receive(:clone?).and_return(false)

      expect { described_class.check! }.to raise_error(FakeAccounts::Refused, /not a snapshot clone/)
    end

    it 'allows a snapshot clone outside production' do
      expect { described_class.check! }.not_to raise_error
    end
  end

  describe '.create!' do
    it 'creates one confirmed reader and one admin with example.test emails, idempotently' do
      described_class.create!
      users = described_class.create!

      expect(users.map(&:email)).to all(end_with('@example.test'))
      expect(users.map(&:role)).to eq(%w[normal_user admin])
      expect(users).to all(be_confirmed)
      expect(User.where('email LIKE ?', '%@example.test').count).to eq(2)
    end
  end
end
