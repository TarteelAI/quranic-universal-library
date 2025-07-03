# frozen_string_literal: true

ActiveAdmin.register DatabaseBackup do
  menu parent: 'Settings'

  filter :database_name
  filter :created_at
  filter :tag

  collection_action :admin_action, method: 'put' do
    if can? :admin, :run_actions
      # Restart sidekiq if it's not running
      Utils::System.start_sidekiq

      case params[:name].to_s
      when 'new_db_dump'
        BackupJob.perform_later
        redirect_to cms_database_backups_path, notice: 'New backup will be started soon'
      when 'sync_quranenc'
        DraftContent::CheckContentChangesJob.perform_later
        redirect_to cms_dashboard_path, notice: 'Sync will starts soon.'
      when 'restart_sidekiq'
        Utils::System.start_sidekiq

        redirect_to cms_dashboard_path, notice:  Utils::System.sidekiq_stopped? ? 'Sorry sidekiq failed to start' : 'Sidekiq started successfully.'
      when 'import_lokalise'
        LokaliseJob.perform_later(action: :import)
      when 'export_lokalise'
        LokaliseJob.perform_later(action: :export)
      when 'clear_cdn_cache'
        urls = params[:urls].to_s.split(',').map(&:strip).reject(&:empty?)
        cache_service = CloudflareCacheClearer.new
        result = cache_service.clear_cache(urls: urls)

        redirect_to cms_dashboard_path, notice: result.to_s
      else
        redirect_to cms_dashboard_path, error: 'Invalid operation.'
      end
    else
      redirect_to cms_dashboard_path, error: 'You are not allowed to perform this action.'
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
