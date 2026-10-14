# Reference tables for the multi-riwayah work (phase 1, task P1.1).
#
# counting_systems: the six madhahib of 'add al-ay (ayah counting).
# qiraat:           the ten canonical readings, each attributed to one counting system.
#
# Both live in the Quran database (QuranApiRecord), hence Verse.connection.
# Rows are loaded from the pinned qiraat-ayah-map files by rake qiraat:seed:reference.
class CreateCountingSystemsAndQiraat < ActiveRecord::Migration[8.0]
  def up
    c = Verse.connection

    c.create_table :counting_systems do |t|
      t.string :slug, null: false            # kufi, madani-first, madani-last, makki, basri, dimashqi
      t.string :name_ar, null: false
      t.string :name_en, null: false
      t.integer :total_ayahs                 # as published by the pinned dataset; never typed by hand
      t.boolean :is_reference, null: false, default: false # true for kufi (the hub every mapping goes through)
      t.text :description_ar
      t.text :description_en
      t.timestamps
    end
    c.add_index :counting_systems, :slug, unique: true

    c.create_table :qiraat do |t|
      t.string :slug, null: false            # asim, nafi, ibn-kathir, abu-amr, ibn-amir, hamza, kisai, abu-jafar, yaqub, khalaf
      t.string :name_ar, null: false
      t.string :name_en, null: false
      t.integer :counting_system_id          # counting_system_associated_with_qari (attributed, not printed)
      t.integer :position                    # canonical order 1..10
      t.text :description
      t.timestamps
    end
    c.add_index :qiraat, :slug, unique: true
    c.add_index :qiraat, :counting_system_id
  end

  def down
    c = Verse.connection
    c.drop_table :qiraat
    c.drop_table :counting_systems
  end
end
