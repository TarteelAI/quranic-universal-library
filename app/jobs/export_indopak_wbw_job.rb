class ExportIndopakWbwJob < ApplicationJob
  queue_as :default
  STORAGE_PATH = "public/exported_indopak"
  
  def perform(original_file_name='indopak_wbw')
    file_name = original_file_name.chomp('.db')
    file_path = "#{STORAGE_PATH}/#{Time.now.to_i}"
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
    ExportRecord.connection.execute("CREATE TABLE words(id integer, sura integer,ayah integer, position integer,
                                      location string, text_uthmani string, text_indopak string, text_imlaei string, text_nastaleeq string, text_qcf_hafs string, code_v1 string,  code_v2 string, audio string, word_type string, trans_bn string, trans_id string, trans_ur string, trans_en string)")
    ExportRecord.table_name = 'words'
  end
  
  def prepare_import_sql()
    Word.find_each do |word|
      w_type         = ExportRecord.connection.quote(word.char_type_name)
      chapter, verse = word.verse_key.split(':')

      text_uthmani           = ExportRecord.connection.quote(word.text_uthmani)
      text_indopak           = ExportRecord.connection.quote(word.text_indopak)
      text_imlaei = ExportRecord.connection.quote(word.text_imlaei)
      code_v1 = ExportRecord.connection.quote(word.code_v1)
      code_v2 = ExportRecord.connection.quote(word.code_v2)
      location = ExportRecord.connection.quote(word.location)
      text_nastaleeq = ExportRecord.connection.quote(word.text_indopak_nastaleeq)
      text_qcf_hafs = ExportRecord.connection.quote(word.text_qpc_hafs)
      audio = ExportRecord.connection.quote(word.audio_url)

      trans_bn = Verse.connection.quote(word.bn_translation&.text)
      trans_id = Verse.connection.quote(word.id_translation&.text)
      trans_ur = Verse.connection.quote(word.ur_translation&.text)
      trans_en = Verse.connection.quote(word.en_translation&.text)

      values          = "(#{word.id}, #{chapter}, #{verse}, #{word.position}, #{location}, #{text_uthmani}, #{text_indopak}, #{text_imlaei},#{text_nastaleeq}, #{text_qcf_hafs}, #{code_v1}, #{code_v2}, #{audio}, #{trans_bn}, #{trans_ur}, #{trans_id}, #{trans_en}, #{w_type})"
      begin
        ExportRecord.connection.execute("INSERT INTO words (id, sura, ayah, position, location, text_uthmani, text_indopak, text_imlaei, text_nastaleeq, text_qcf_hafs, code_v1, code_v2, audio, trans_bn, trans_ur, trans_id, trans_en, word_type) VALUES #{values}")
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




