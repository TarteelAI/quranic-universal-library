# frozen_string_literal: true
# == Schema Information
#
# Table name: database_backups
#
#  id            :bigint           not null, primary key
#  database_name :string
#  file          :string
#  size          :string
#  tag           :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

class DatabaseBackup < ApplicationRecord
  mount_uploader :file, DatabaseBackupUploader
end
