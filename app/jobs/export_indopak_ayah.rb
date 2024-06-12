class ExportIndopakAyah < ApplicationJob
  queue_as :default
  STORAGE_PATH = "public/exported_indopak"
  
  def perform(original_file_name)
    original_file_name='indopak'
    
    file_name = original_file_name.chomp('.db')
    file_path = "#{STORAGE_PATH}/ayah"
    require 'fileutils'
    FileUtils::mkdir_p file_path
    
    prepare_db("#{file_path}/#{file_name}.db")
    
    prepare_import_sql
    
    # zip the file
    `bzip2 #{file_path}/#{file_name}.db`
    
    # return the db file path
    "#{file_path}/#{file_name}.db.bz2"
  end
  
  def prepare_db(file_path)
    ExportRecord.establish_connection connection_config(file_path)
    ExportRecord.connection.execute("CREATE TABLE indopak(sura integer,ayah integer, text_indopak text,
                                      primary key(sura, ayah))")
    ExportRecord.table_name = 'indopak'
  end
  
  def prepare_import_sql()
    Verse.order("verse_index ASC").find_each do |verse|
      chapter, ayah = verse.verse_key.split(':')
      text_indopak           = ExportRecord.connection.quote(verse.text_indopak)
      
      
      values          = "(#{chapter}, #{ayah}, #{text_indopak})"
      begin
        ExportRecord.connection.execute("INSERT INTO indopak (sura, ayah, text_indopak) VALUES #{values}")
      rescue Exception => e
        puts e.message
      end
    end
  end
  
  def connection_config(file_name)
    { adapter:  'sqlite3',
      database: file_name
    }
  end
  
  class ExportRecord < ActiveRecord::Base
  end
end
