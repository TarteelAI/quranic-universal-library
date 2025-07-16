# == Schema Information
#
# Table name: quran_table_details
#
#  id         :bigint           not null, primary key
#  enteries   :integer
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class QuranTableDetail < ApplicationRecord
  def self.refresh_tables_meta
    (Verse.connection.tables - ['refresh_tables_meta']).each do |name|
      table = QuranTableDetail.where(name: name).first_or_create

      result = Verse.connection.execute "select count(*) from #{name}"
      table.update(records_count: result.first['count'])
    end
  end

  def readonly?
    true
  end

  def load_table(page, limit)
    QuranTable.table_name = name
    QuranTable.page(page).per(limit)    
  end

  def load_record(id)
    QuranTable.table_name = name
    QuranTable.find(id)
  end
end
