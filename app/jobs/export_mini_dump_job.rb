class ExportMiniDumpJob < ApplicationJob
  queue_as :default
  STORAGE_PATH = "public/assets/exported_databases"

  def perform
    # Only run this is development environment
    if Rails.env.development?
      cleanup_data
      prepare_dump
    else
      raise "can't run this job in #{Rails.env} environment."
    end
  end

  def cleanup_data
    translation = [131, 54, 39, 149]
    recitation = [7, 8]
    word_translations = [104, 59]
    tafsirs = [16, 157]
    info = [58]

    # Keep first 15 ayah of each surah
=begin
    Chapter.find_each do |c|
      verse_to_remove = c.verses.where("verse_number > 15")
      words = Word.where(verse_id: verse_to_remove)
      WordTranslation.where(word_id: words).delete_all
      words.delete_all

      translations = Translation.where(verse_id: verse_to_remove)
      FootNote.where(translation_id: translations).delete_all
      translations.delete_all

      verse_to_remove.delete_all
    end
=end



    # Remove data we don't want to include in mini dump
    WordTranslation.where.not(resource_content_id: word_translations).delete_all
    Translation.where.not(resource_content_id: translation).delete_all
    Tafsir.where.not(resource_content_id: tafsirs).delete_all
    ChapterInfo.where.not(resource_content_id: info).delete_all
    AudioFile.where.not(recitation_id: recitation).delete_all

    WordLemma.delete_all
    Lemma.delete_all
    VerseLemma.delete_all

    WordStem.delete_all
    Stem.delete_all
    VerseStem.delete_all

    VerseRoot.delete_all
    WordRoot.delete_all
    Root.delete_all

    DataSource.delete_all

    # DROP OLD tables
    ActiveRecord::Migration.drop_table "quran.image"
    ActiveRecord::Migration.drop_table "quran.text"
    ActiveRecord::Migration.drop_table "quran.word_translation"

    ActiveRecord::Migration.execute "DROP VIEW quran.text_font"
    ActiveRecord::Migration.execute "DROP VIEW quran.text_lemma"
    ActiveRecord::Migration.execute "DROP VIEW quran.text_root"
    ActiveRecord::Migration.execute "DROP VIEW quran.text_stem"
    ActiveRecord::Migration.execute "DROP VIEW quran.text_token"

    ActiveRecord::Migration.drop_table "quran.word_font"
    ActiveRecord::Migration.drop_table "quran.word_lemma"
    ActiveRecord::Migration.drop_table "quran.word_root"
    ActiveRecord::Migration.drop_table "quran.word_stem"
    ActiveRecord::Migration.drop_table "quran.word"

    ActiveRecord::Migration.drop_table "audio.file"
    ActiveRecord::Migration.drop_table "media.content"
    ActiveRecord::Migration.drop_table "media.resource"

    ActiveRecord::Migration.drop_table "content.translation"
    ActiveRecord::Migration.drop_table "content.tafsir_ayah"
    ActiveRecord::Migration.drop_table "content.transliteration"

    ActiveRecord::Migration.drop_table "quran.ayah"

    ActiveRecord::Migration.drop_table "quran.token"
    ActiveRecord::Migration.drop_table "quran.stem"
    ActiveRecord::Migration.drop_table "quran.root"
    ActiveRecord::Migration.drop_table "quran.surah"
    ActiveRecord::Migration.drop_table "quran.arabic_transliterations"
  end

  def prepare_dump
    `pg_dump --file='mini_dump.sql' --no-owner --no-privileges quran_dev`
    `pg_dump -b -E UTF-8 -f mini_dump --no-owner --no-privileges --no-tablespaces -F c -Z 9 --clean quran_dev`
  end
end
