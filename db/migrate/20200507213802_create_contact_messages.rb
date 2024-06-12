class CreateContactMessages < ActiveRecord::Migration[5.2]
  def change
    create_table :contact_messages do |t|
      t.string :name
      t.string :email
      t.text :detail
      t.string :subject
      t.string :url

      t.timestamps
    end
  end
end
