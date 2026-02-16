namespace :db_backups do
  desc "Migrate database backup files from CarrierWave to ActiveStorage. Set DRY_RUN=true to preview without changes."
  task migrate_to_activestorage: :environment do
    dry_run = ENV['DRY_RUN'].present?

    puts "DRY RUN MODE - No files will be migrated" if dry_run
    puts "Starting migration from CarrierWave to ActiveStorage..."

    results = {
      database_backup: { migrated: 0, failed: 0, skipped: 0, errors: [] },
      resource_content: { migrated: 0, failed: 0, skipped: 0, errors: [] }
    }

    # Migrate DatabaseBackup records
    puts "Migrating DatabaseBackup records..."
    database_backups = DatabaseBackup.where.not(file: [nil, ''])
    total_db_backups = database_backups.count
    puts "Found #{total_db_backups} records with CarrierWave files"

    database_backups.find_each.with_index(1) do |backup, index|
      result = migrate_database_backup(backup, index, total_db_backups, dry_run)

      case result[:status]
      when :migrated
        results[:database_backup][:migrated] += 1
      when :skipped
        results[:database_backup][:skipped] += 1
      when :failed
        results[:database_backup][:failed] += 1
        results[:database_backup][:errors] << { id: backup.id, error: result[:error] }
      end
    end

    # Migrate ResourceContent records
    puts "Migrating ResourceContent records..."
    resource_contents = ResourceContent.where.not(sqlite_db: [nil, ''])
    total_resources = resource_contents.count
    puts "Found #{total_resources} records with CarrierWave files"

    resource_contents.find_each.with_index(1) do |resource, index|
      result = migrate_resource_content(resource, index, total_resources, dry_run)

      case result[:status]
      when :migrated
        results[:resource_content][:migrated] += 1
      when :skipped
        results[:resource_content][:skipped] += 1
      when :failed
        results[:resource_content][:failed] += 1
        results[:resource_content][:errors] << { id: resource.id, error: result[:error] }
      end
    end

    print_summary(results, dry_run)
  end

  def download_to_tempfile(source_file, prefix)
    require 'open-uri'

    ext = File.extname(source_file.path || source_file.identifier || '')
    tempfile = Tempfile.new([prefix, ext], binmode: true)

    if source_file.path && File.exist?(source_file.path)
      IO.copy_stream(source_file.path, tempfile)
    else
      URI.open(source_file.url) { |remote| IO.copy_stream(remote, tempfile) }
    end

    tempfile.rewind
    tempfile
  end

  def migrate_database_backup(backup, index, total, dry_run)
    prefix = "[#{index}/#{total}] DatabaseBackup ##{backup.id}"

    if backup.backup_file.attached?
      puts "#{prefix} - Skipped (already migrated)"
      return { status: :skipped }
    end

    unless backup.file.present? && backup.file.file.present?
      puts "#{prefix} - Failed: CarrierWave file not present"
      return { status: :failed, error: "CarrierWave file not present" }
    end

    if dry_run
      file_path = backup.file.path rescue backup.file.url
      puts "#{prefix} - Would migrate: #{file_path}"
      return { status: :migrated }
    end

    tempfile = nil
    begin
      source_file = backup.file
      filename = File.basename(source_file.path || source_file.identifier || "backup_#{backup.id}.sql")
      content_type = source_file.content_type || 'application/octet-stream'

      tempfile = download_to_tempfile(source_file, 'db_backup')

      backup.backup_file.attach(
        io: tempfile,
        filename: filename,
        content_type: content_type
      )

      if backup.backup_file.attached?
        puts "#{prefix} - Success (#{filename})"
        { status: :migrated }
      else
        puts "#{prefix} - Failed: Attachment verification failed"
        { status: :failed, error: "Attachment verification failed" }
      end
    rescue => e
      puts "#{prefix} - Failed: #{e.message}"
      { status: :failed, error: e.message }
    ensure
      tempfile&.close!
    end
  end

  def migrate_resource_content(resource, index, total, dry_run)
    prefix = "[#{index}/#{total}] ResourceContent ##{resource.id}"

    if resource.sqlite_database.attached?
      puts "#{prefix} - Skipped (already migrated)"
      return { status: :skipped }
    end

    unless resource.sqlite_db.present? && resource.sqlite_db.file.present?
      puts "#{prefix} - Failed: CarrierWave file not present"
      return { status: :failed, error: "CarrierWave file not present" }
    end

    if dry_run
      file_path = resource.sqlite_db.path rescue resource.sqlite_db.url
      puts "#{prefix} - Would migrate: #{file_path}"
      return { status: :migrated }
    end

    tempfile = nil
    begin
      source_file = resource.sqlite_db
      filename = File.basename(source_file.path || source_file.identifier || "resource_#{resource.id}.sqlite")
      content_type = source_file.content_type || 'application/x-sqlite3'

      tempfile = download_to_tempfile(source_file, 'sqlite_db')

      resource.sqlite_database.attach(
        io: tempfile,
        filename: filename,
        content_type: content_type
      )

      if resource.sqlite_database.attached?
        puts "#{prefix} - Success (#{filename})"
        { status: :migrated }
      else
        puts "#{prefix} - Failed: Attachment verification failed"
        { status: :failed, error: "Attachment verification failed" }
      end
    rescue => e
      puts "#{prefix} - Failed: #{e.message}"
      { status: :failed, error: e.message }
    ensure
      tempfile&.close!
    end
  end

  def print_summary(results, dry_run)
    puts ""
    puts "=" * 50
    puts dry_run ? "DRY RUN SUMMARY" : "MIGRATION SUMMARY"
    puts "=" * 50
    puts "DatabaseBackup:"
    puts "  #{dry_run ? 'Would migrate' : 'Migrated'}: #{results[:database_backup][:migrated]}"
    puts "  Skipped: #{results[:database_backup][:skipped]}"
    puts "  Failed: #{results[:database_backup][:failed]}"
    puts ""
    puts "ResourceContent:"
    puts "  #{dry_run ? 'Would migrate' : 'Migrated'}: #{results[:resource_content][:migrated]}"
    puts "  Skipped: #{results[:resource_content][:skipped]}"
    puts "  Failed: #{results[:resource_content][:failed]}"

    all_errors = results[:database_backup][:errors] + results[:resource_content][:errors]
    if all_errors.any?
      puts ""
      puts "Failed records:"
      results[:database_backup][:errors].each do |err|
        puts "  DatabaseBackup ##{err[:id]}: #{err[:error]}"
      end
      results[:resource_content][:errors].each do |err|
        puts "  ResourceContent ##{err[:id]}: #{err[:error]}"
      end
    end

    puts ""
    puts dry_run ? "Run without DRY_RUN=true to perform actual migration." : "Migration complete."
  end
end
