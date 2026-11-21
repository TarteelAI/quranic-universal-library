namespace :dev do
  desc 'Create a fake reader and a fake admin (@example.test) in a local snapshot clone'
  task fake_accounts: :environment do
    # Creating a user enqueues a welcome email; nothing may reach Sidekiq or a mail server.
    ActiveJob::Base.queue_adapter = :test
    ActionMailer::Base.perform_deliveries = false

    FakeAccounts.create!.each do |user|
      puts "#{user.email} (#{user.role}), password: #{FakeAccounts::PASSWORD}"
    end
  rescue FakeAccounts::Refused => e
    abort e.message
  end
end
