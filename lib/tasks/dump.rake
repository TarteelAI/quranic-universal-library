namespace :dump do
  desc "Create mini dump"
  task create: :environment do
    if !Rails.env.development?
      raise "This task can only be run in development environment"
    end

    PaperTrail.enabled = false
    verses = Verse.where("verse_number > 20")
    verse_ids = verses.pluck(:id)
    Audio::Segment.where("verse_id IN(?)", verse_ids).delete_all
    Translation.where("verse_number > 20").delete_all

    verses.each do |v|
      Morphology::WordVerbForm.joins(:word).where(morphology_words: { verse_id: v.id }).delete_all
      Morphology::WordSegment.joins(:word).where(morphology_words: { verse_id: v.id }).delete_all
      Morphology::Word.where(verse_id: v.id).delete_all
      AyahTheme.where("verse_id_from >= ?", v.id).delete_all
    end
    Morphology::DerivedWord.delete_all

    Audio::ChangeLog.delete_all
    AudioFile.where("verse_id IN(?)", verse_ids).delete_all
    ChapterInfo.where.not(language_id: 38).delete_all

    ArabicTransliteration.where("verse_id IN(?)", verse_ids).delete_all
    VerseTopic.where("verse_id IN(?)", verse_ids).delete_all

    WordStem.joins(:word).where(word: { verse_id: verse_ids }).delete_all
    WordLemma.joins(:word).where(word: { verse_id: verse_ids }).delete_all
    WordRoot.joins(:word).where(word: { verse_id: verse_ids }).delete_all

    t = Topic.first(50)
    Topic.where.not(id: t.pluck(:id)).each do |t|
      t.destroy rescue nil
    end

    NavigationSearchRecord.delete_all
    WordTranslation.joins(:word).where(word: { verse_id: verse_ids }).delete_all
    Word.where("verse_id IN(?)", verse_ids).delete_all

    Word.joins("LEFT JOIN verses ON verses.id = words.verse_id")
        .where(verses: { id: nil })
        .delete_all

    Chapter.find_each do |chapter|
      chapter.slugs.where.not(locale: 'en').delete_all
      chapter.translated_names.where.not(language_id: 38).delete_all
    end

    Audio::ChapterAudioFile.where("chapter_id > 10").delete_all

    ApiClient.delete_all
    ApiClientRequestStat.delete_all

    DataSource.update_all(name: 'Demo', url: 'Demo')

    # Create SQL dump
    `pg_dump quran_dev > dumps/quran_dev.sql`

    # Create binary dump
    `pg_dump -b -E UTF-8 -f dumps/quran_dev.dump --no-owner --no-privileges --no-tablespaces -F c -Z 9 --clean quran_dev`
  end

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