class CreateFaqs < ActiveRecord::Migration[7.0]
  def change
    create_table :faqs do |t|
      t.string :question
      t.text :answer
      t.integer :position
      t.boolean :published, default: false

      t.timestamps
    end

    add_index :faqs, [:position, :published]
  end
end
