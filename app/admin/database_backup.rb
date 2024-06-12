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
ActiveAdmin.register DatabaseBackup do
  menu parent: 'Settings'

  filter :database_name
  filter :created_at
  filter :tag

  collection_action :admin_action, method: 'put' do
    case params[:name].to_s
    when 'new_db_dump'
      BackupJob.perform_later
      redirect_to admin_database_backups_path, notice: 'New backup will be started soon'
    when 'sync_quranenc'
      QuranEnc::UpdatesCheckerJob.perform_later
      redirect_to admin_dashboard_path, notice: 'Sync will starts soon.'
    when 'restart_sidekiq'
      Utils::System.start_sidekiq

      redirect_to admin_dashboard_path, notice:  Utils::System.sidekiq_stopped? ? 'Sorry sidekiq failed to start' : 'Sidekiq started successfully.'
    when 'import_lokalise'
      LokaliseJob.perform_later(action: :import)
    when 'export_lokalise'
      LokaliseJob.perform_later(action: :export)
    else
      redirect_to admin_dashboard_path, error: 'Invalid operation.'
    end
  end

  index do
    id_column
    column :database_name

    column :created_at
    column :tag
    column :size
    column :download do |backup|
      link_to 'Download', backup.file.url
    end
  end

  permit_params do
    %i[database_name tag]
  end
end
