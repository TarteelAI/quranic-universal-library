class CreateProofReadComments < ActiveRecord::Migration[5.1]
  def change
    create_table :proof_read_comments do |t|
      t.references :user
      t.references :resource, polymorphic: true, null: false, index: true
      t.text :text

      t.timestamps
    end
  end
end
