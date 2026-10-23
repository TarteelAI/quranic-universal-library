# Surah info edits are saved as drafts and go live once approved.
class CreateDraftSurahInfos < ActiveRecord::Migration[8.0]
  def change
    create_table :draft_surah_infos do |t|
      t.integer :resource_content_id, index: true
      t.integer :chapter_id, index: true
      t.integer :user_id
      t.text :current_short_text
      t.text :draft_short_text
      t.text :current_text
      t.text :draft_text
      t.boolean :text_matched, default: false, index: true
      t.boolean :need_review, default: true, index: true
      t.boolean :imported, default: false, index: true
      t.jsonb :meta_data, default: {}
      t.timestamps
    end
  end
end
