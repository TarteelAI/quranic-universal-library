#!/usr/bin/env ruby

# Batch processor for multiple AudioSegmentParser files
# Usage: ruby lib/batch_audio_segment_parser.rb

require_relative 'audio_segment_parser'
require 'find'

class BatchAudioSegmentParser
  def initialize(data_directory = "data")
    @data_directory = data_directory
  end

  def process_all_files
    puts "Scanning directory: #{@data_directory}"
    
    time_machine_files = find_time_machine_files
    puts "Found #{time_machine_files.length} time-machine.json files"
    
    time_machine_files.each_with_index do |file_path, index|
      puts "\nProcessing file #{index + 1}/#{time_machine_files.length}: #{file_path}"
      
      begin
        parser = AudioSegmentParser.new(file_path)
        puts "  Reciter ID: #{parser.reciter_id}, Surah: #{parser.surah_number}"
        
        parser.parse_and_save
        puts "  ✓ Successfully processed"
      rescue => e
        puts "  ✗ Error processing file: #{e.message}"
        puts "  Backtrace: #{e.backtrace.first(3).join("\n    ")}"
      end
    end
    
    puts "\nBatch processing completed!"
  end

  def find_time_machine_files
    time_machine_files = []
    
    Find.find(@data_directory) do |path|
      if File.basename(path) == "time-machine.json"
        time_machine_files << path
      end
    end
    
    time_machine_files
  end

  def process_specific_reciter(reciter_id)
    puts "Processing files for reciter ID: #{reciter_id}"
    
    time_machine_files = find_time_machine_files.select do |file_path|
      folder_name = File.basename(File.dirname(file_path))
      folder_name[0..3].to_i == reciter_id
    end
    
    puts "Found #{time_machine_files.length} files for reciter #{reciter_id}"
    
    time_machine_files.each do |file_path|
      begin
        parser = AudioSegmentParser.new(file_path)
        puts "  Processing Surah #{parser.surah_number}..."
        parser.parse_and_save
        puts "  ✓ Completed"
      rescue => e
        puts "  ✗ Error: #{e.message}"
      end
    end
  end

  def process_specific_surah(surah_number)
    puts "Processing files for Surah: #{surah_number}"
    
    time_machine_files = find_time_machine_files.select do |file_path|
      folder_name = File.basename(File.dirname(file_path))
      folder_name[4..7].to_i == surah_number
    end
    
    puts "Found #{time_machine_files.length} files for Surah #{surah_number}"
    
    time_machine_files.each do |file_path|
      begin
        parser = AudioSegmentParser.new(file_path)
        puts "  Processing Reciter #{parser.reciter_id}..."
        parser.parse_and_save
        puts "  ✓ Completed"
      rescue => e
        puts "  ✗ Error: #{e.message}"
      end
    end
  end
end

# Example usage
if __FILE__ == $0
  batch_parser = BatchAudioSegmentParser.new
  
  if ARGV.empty?
    puts "Processing all files..."
    batch_parser.process_all_files
  elsif ARGV[0] == "--reciter" && ARGV[1]
    batch_parser.process_specific_reciter(ARGV[1].to_i)
  elsif ARGV[0] == "--surah" && ARGV[1]
    batch_parser.process_specific_surah(ARGV[1].to_i)
  else
    puts "Usage:"
    puts "  ruby lib/batch_audio_segment_parser.rb                    # Process all files"
    puts "  ruby lib/batch_audio_segment_parser.rb --reciter 2       # Process specific reciter"
    puts "  ruby lib/batch_audio_segment_parser.rb --surah 2         # Process specific surah"
  end
end
