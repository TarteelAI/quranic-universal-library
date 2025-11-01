class AddEsIndexesJsonbTmpToLanguages < ActiveRecord::Migration[8.0]
  def change
    c = Language.connection

    c.add_column :languages, :es_indexes_tmp, :jsonb, default: [], null: false
  end
end

