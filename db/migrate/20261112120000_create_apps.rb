# Apps built with QUL, as rows in the CMS database: the submissions sent from the form on /apps
# (unpublished until an editor approves them) and, from 002-14, the directory itself. `contact`
# is the submitter's address and is shown to editors only. The icon is an Active Storage
# attachment. Reversible: a rollback drops the table; icon attachments of App rows stay behind
# and are purged by hand.
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
    end
  end
end
