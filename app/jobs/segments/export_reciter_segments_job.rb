module Segments
  class ExportReciterSegmentsJob < ApplicationJob
    queue_as :default

    def perform(user_id, reciter_id)
      ::Segments::Database.current.load_db
      user = User.find(user_id)
      reciter = ::Segments::Reciter.find(reciter_id)
      
      begin
        exporter = AudioSegment::SurahBySurah.new(nil)
        db_file_path = exporter.export_segments_positions(reciter_id, 'db')
        
        zip_file_path = create_zip_file(reciter, db_file_path)
        
        SegmentsMailer.send_reciter_data(user, reciter, zip_file_path).deliver_now
        
        File.delete(db_file_path) if File.exist?(db_file_path)
        File.delete(zip_file_path) if File.exist?(zip_file_path)
        
        Rails.logger.info "Successfully exported and emailed segments data for reciter #{reciter_id} to user #{user_id}"
      rescue => e
        Rails.logger.error "Error in Segments::ExportReciterSegmentsJob for reciter #{reciter_id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        SegmentsMailer.send_export_error(user, reciter, e.message).deliver_now
      end
    end

    private

    def create_zip_file(reciter, db_file_path)
      require 'zip'
      require 'json'
      
      temp_dir = Rails.root.join('tmp', "reciter_#{reciter.id}_#{Time.current.to_i}")
      FileUtils.mkdir_p(temp_dir)
      
      temp_db_path = temp_dir.join('segments_database.db')
      FileUtils.cp(db_file_path, temp_db_path)
      
      metadata = {
        reciter_name: reciter.name,
        reciter_id: reciter.id,
        generated_at: Time.current.iso8601,
        description: 'Segments position data exported from Segments::Position table with ayah boundaries',
        table_schema: {
          table_name: 'timings',
          columns: ['sura', 'ayah', 'start_time', 'end_time', 'words'],
          description: 'Ayah-level timing data with word-level segments. Start/end times from ayah boundaries, words from positions.'
        }
      }
      
      File.write(temp_dir.join('metadata.json'), JSON.pretty_generate(metadata))
      
      zip_path = Rails.root.join('tmp', "reciter_#{reciter.id}_segments_#{Time.current.to_i}.zip")
      
      Zip::File.open(zip_path, Zip::File::CREATE) do |zipfile|
        Dir.glob(temp_dir.join('*')).each do |file_path|
          zipfile.add(File.basename(file_path), file_path)
        end
      end
      
      # Clean up temporary directory
      FileUtils.rm_rf(temp_dir)
      
      zip_path.to_s
    end
  end
end