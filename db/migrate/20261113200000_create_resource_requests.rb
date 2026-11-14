# Resource requests and their votes, as rows in the CMS database. A request is a signed-in user's
# ask for a resource QUL does not have; editors set its status and can hide it. A vote is one row
# per user and request, which the unique index holds also when two votes race.
# Reversible: a rollback drops both tables with every request and vote in them.
class CreateResourceRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :resource_requests do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.string :resource_type, null: false
      t.string :language
      t.string :status, null: false, default: 'open'
      t.boolean :hidden, null: false, default: false
      t.references :user, foreign_key: { on_delete: :nullify }
      t.timestamps
    end

    create_table :resource_request_votes do |t|
      t.references :resource_request, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :resource_request_votes, [:resource_request_id, :user_id], unique: true,
                                                                         name: 'index_resource_request_votes_unique'
  end
end
