namespace :clean_up_old_tables do
  task remove_old_tables: :environment do
    views = [
      'text_font',
      'text_lemma',
      'text_root',
      'text_stem',
      'text_token'
    ]

    schemas = [
      'audio',
      'media',
      'i18n',
      'content'
    ]

    tables = [
      'image',
      'word_translation',
      'word_corpus',
      'word_lemma',
      'word_root',
      'word_font',
      'ayah',
      'surah',
      'text',
      'root',
      'stem',
      'word_stem',
      'token',
      'tokens',
      'verse',
      'view',
      'char_type',
      'lemma',
      'audio.file',
      'audio.reciter',
      'audio.style',
      'books',
      "qr_authors",
      "qr_comments",
      "qr_filters",
      "qr_post_filters",
      "qr_post_tags",
      "qr_posts",
      "qr_reported_issues",
      "qr_rooms",
      "qr_tags",
      'word'
    ]

    connection = Verse.connection

    views.each do |v|
      connection.execute "DROP VIEW IF EXISTS #{v};"
    end

    schemas.each do |s|
      connection.execute "DROP SCHEMA IF EXISTS #{s} CASCADE;"
    end

    tables.each do |t|
      begin
        connection.drop_table(t, cascade: true)
      rescue Exception => e
        puts "========= failed to remove table #{t}"
        puts e.message
      end
    end
  end
end