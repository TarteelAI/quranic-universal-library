# frozen_string_literal: true
require 'sidekiq-scheduler'

class BackupJob < ApplicationJob
  queue_as :default
  include Sidekiq::Status::Worker

  def perform(tag=nil)
    if Rails.env.production?
      require "#{Rails.root}/lib/utils/db_backup.rb"
      Utils::DbBackup.run(tag)
    end
  end
end