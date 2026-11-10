# Clearly fake accounts for signing in to a local clone: one reader and one admin.
# Run with `bin/rails dev:fake_accounts`.
class FakeAccounts
  PASSWORD = 'fake-account-password'
  ACCOUNTS = [
    { email: 'reader@example.test', first_name: 'Fake', last_name: 'Reader', role: :normal_user },
    { email: 'admin@example.test', first_name: 'Fake', last_name: 'Admin', role: :admin }
  ].freeze

  class Refused < StandardError; end

  def self.check!(env: Rails.env, connection: ApplicationRecord.connection)
    raise Refused, 'Fake accounts are never created in production.' if env.production?
    return if SnapshotClone.clone?(connection)

    raise Refused, "#{connection.current_database} is not a snapshot clone (see bin/snapshot-clones)."
  end

  def self.create!
    check!

    ACCOUNTS.map do |attributes|
      user = User.find_or_initialize_by(email: attributes[:email])
      user.assign_attributes(attributes.except(:email))
      user.password = PASSWORD
      user.skip_confirmation!
      user.save!
      user
    end
  end
end
