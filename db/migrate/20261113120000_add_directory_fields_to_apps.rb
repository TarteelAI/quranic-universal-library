# The apps directory moves into the `apps` table (002-14): the fields the directory shows that a
# submission does not ask for (`kind`, `description`), the public page that shows the app credits
# QUL (`evidence`), and `import_key`, the id of the config/apps.yml entry a row was imported from
# (`apps:import`), null for a submission. Reversible: a rollback removes the four columns and
# their values.
class AddDirectoryFieldsToApps < ActiveRecord::Migration[8.0]
  def change
    change_table :apps, bulk: true do |t|
      t.string :import_key
      t.string :kind
      t.text :description
      t.string :evidence
      t.index :import_key, unique: true
    end
  end
end
