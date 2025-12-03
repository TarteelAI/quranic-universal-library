module Segments
  class Database < ApplicationRecord
    self.table_name = 'segments_databases'
    has_one_attached :db_file, service: Rails.env.production? ? :qul_segments : :local

    #TODO: Use service_prefix after upgrading to Rails 7.1
    # and remove this
    before_create do
      db_file.blob.key = File.join("segments", SecureRandom.hex(24))
    end

    def self.current
      where(active: true).first
    end

    def load_db
      download_db
      init_db_connection
    end

    protected
    def download_db
      require "zip"
      zip_temp_path = Rails.root.join("tmp", "segments_upload_#{id}.zip")
      db_dir = db_file_path.dirname

      FileUtils.mkdir_p(db_dir)

      File.open(zip_temp_path, "wb") { |f| f.write(db_file.download) }

      Zip::File.open(zip_temp_path) do |zip_file|
        zip_file.each do |entry|
          if entry.name.ends_with?(".db")
            entry.extract(db_file_path) { true }
            break
          end
        end
      end

      File.delete(zip_temp_path) if File.exist?(zip_temp_path)
    end

    def init_db_connection
      raise "DB file not found at #{db_file_path}" unless db_file_path.exist?

      Segments::Base.establish_connection(
        adapter: 'sqlite3',
        database: db_file_path.to_s
      )

      segment_models.each(&:reset_column_information)
    end

    def db_file_path
      Rails.root.join("tmp", "segments#{id}_db", "segments_database.db")
    end

    def segment_models
      [
        Segments::Detection,
        Segments::Failure,
        Segments::Log,
        Segments::Position,
        Segments::Reciter
      ]
    end
  end
end