class RemoveWbwText < ActiveRecord::Migration[7.0]
  def change
    drop_table :wbw_texts
    drop_table :wbw_translations
  end
end
