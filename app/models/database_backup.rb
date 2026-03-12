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
  has_one_attached :backup_file, service: :database_backups

  def file_url
    Rails.application.routes.url_helpers.rails_blob_path(backup_file, only_path: true) if backup_file.attached?
  end

  alias_method :url, :file_url
end
