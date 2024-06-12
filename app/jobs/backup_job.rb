# frozen_string_literal: true
require 'sidekiq-scheduler'

class BackupJob < ApplicationJob
  queue_as :default
  include Sidekiq::Status::Worker

  def perform(tag=nil)
    if Rails.env.production?
      require "#{Rails.root}/lib/utils/db_backup.rb"
      Utils::DbBackup.run(tag)

      # Delete old dumps
      # db_dumps = DatabaseBackup.where(tag: nil).where("created_at < ?", 1.month.ago).order("created_at asc")

      #if db_dumps.count > 100
        # Lets keep first 100 backups. There are 3 dbs, so we're keeping aboutt 33 backups for each db
        # db_dumps.first(db_dumps.count-100).each &:destroy
      #end
    end
  end
end