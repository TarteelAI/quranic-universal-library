class AddGaplessRecitationToRecitations < ActiveRecord::Migration[8.0]
  def change
    c = Recitation.connection

    c.add_column :recitations, :gapless_recitation_id, :integer, if_not_exists: true
    c.add_index :recitations, :gapless_recitation_id, unique: true, if_not_exists: true
  end
end
