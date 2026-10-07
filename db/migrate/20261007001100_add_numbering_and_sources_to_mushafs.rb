# Phase 5, task P5.1: a mushaf names its numbering and its sources.
#
# numbering_id   which ayah ends the layout prints (Kufi for every existing mushaf)
# pdf_url        the printed edition to compare against (was a case on id)
# source_package the publisher package the layout came from
# layout_source  manual | generated | svg-verified
class AddNumberingAndSourcesToMushafs < ActiveRecord::Migration[8.0]
  def up
    c = Verse.connection
    c.add_column :mushafs, :numbering_id, :integer
    c.add_column :mushafs, :pdf_url, :string
    c.add_column :mushafs, :source_package, :string
    c.add_column :mushafs, :layout_source, :string, null: false, default: 'manual'
    c.add_index :mushafs, :numbering_id
  end

  def down
    c = Verse.connection
    c.remove_index :mushafs, :numbering_id
    c.remove_column :mushafs, :layout_source
    c.remove_column :mushafs, :source_package
    c.remove_column :mushafs, :pdf_url
    c.remove_column :mushafs, :numbering_id
  end
end
