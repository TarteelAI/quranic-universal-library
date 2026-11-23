# Apps built with QUL, as rows in the CMS database: the apps directory (/apps) and the
# submissions sent from its form, unpublished until an editor approves them. `contact` is the
# submitter's address and is shown to editors only. `project_type` is what the entry is (app,
# library, tool or data) and `platforms` where an app runs. `evidence` is the public page that
# shows the app credits QUL. `import_key` is the id of the config/apps.yml entry a row was
# imported from (`apps:import`), null for a submission. The icon is an Active Storage attachment.
# Reversible: a rollback drops the table; icon attachments of App rows stay behind and are purged
# by hand.
class CreateApps < ActiveRecord::Migration[8.0]
  def change
    create_table :apps do |t|
      t.string :name, null: false
      t.string :url, null: false
      t.string :platforms, array: true, null: false, default: []
      t.string :uses, array: true, null: false, default: []
      t.string :contact
      t.boolean :consent, null: false, default: false
      t.boolean :featured, null: false, default: false
      t.boolean :published, null: false, default: false
      t.references :user, foreign_key: { on_delete: :nullify }
      t.timestamps
      t.string :import_key, index: { unique: true }
      t.string :kind
      t.text :description
      t.string :evidence
      t.string :project_type, null: false, default: 'app'
      t.string :app_store_url
      t.string :play_store_url
      t.string :source_url
    end
  end
end
