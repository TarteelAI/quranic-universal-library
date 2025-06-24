class AddApprovedToRecitation < ActiveRecord::Migration[7.0]
  def change
    c = Recitation.connection
    c.add_column :recitations, :approved, :boolean, default: true
    c.add_column :recitations, :description, :text
  end
end
