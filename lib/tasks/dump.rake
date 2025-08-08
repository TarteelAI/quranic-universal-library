namespace :dump do
  task create_mini_dump: :environment do
    abort("This task can only be run in development environment") unless Rails.env.development?

    PaperTrail.enabled = false

    verses = Verse.where("verse_number > 20")
    verse_ids = verses.pluck(:id)
    word_ids = Word.where(verse_id: verse_ids).pluck(:id)

    puts "Pruning Deleting translations, tafsirs, footnotes etc"
    # Clear Quran
    FootNote.where(resource_content_id: 132).delete_all
    Translation.where(resource_content_id: 131).delete_all
    Translation.where(verse_number: 21..).delete_all
    Tafsir.where(verse_number: 21..).delete_all
    FootNote.left_outer_joins(:translation).where(translation: { id: nil }).delete_all
    Transliteration.where(resource_type: 'Verse', resource_id: verse_ids).delete_all
    Transliteration.where(resource_type: 'Word', resource_id: word_ids).delete_all

    puts "Pruning Deleting morphology data"
    Morphology::WordSegment.update_all(topic_id: nil, root_id: nil)
    Morphology::WordVerbForm.joins(:word).where(morphology_words: { verse_id: verse_ids }).delete_all
    Morphology::WordSegment.joins(:word).where(morphology_words: { verse_id: verse_ids }).delete_all
    Morphology::WordSegment.where(root_id: Root.where("id > 500")).delete_all
    Morphology::Word.where(verse_id: verse_ids).delete_all
    Morphology::DerivedWord.where(verse_id: verse_ids).delete_all
    Morphology::DerivedWord.left_outer_joins(:word).where(word: { id: nil }).delete_all
    Morphology::PhraseVerse.where(verse_id: verse_ids).delete_all
    Morphology::Phrase.where(source_verse_id: verse_ids).delete_all

    puts "Pruning grammar data"
    TajweedWord.delete_all
    Mushaf.where.not(id: [1,2,5,6]).delete_all
    AyahTheme.where(verse_id_from: verse_ids).delete_all
    TajweedWord.where(verse_id: verse_ids).delete_all
    WordCorpus.where(word_id: word_ids).delete_all

    Stem.where("id > 500").delete_all
    Lemma.where("id > 500").delete_all
    Root.where("id > 500").delete_all

    VerseRoot.where.not(id: verses.pluck(:verse_root_id)).delete_all
    VerseStem.where.not(id: verses.pluck(:verse_stem_id)).delete_all
    VerseLemma.where.not(id: verses.pluck(:verse_lemma_id)).delete_all

    puts "Pruning audio data"
    Audio::Segment.where(verse_id: verse_ids).delete_all
    Audio::ChangeLog.delete_all
    AudioFile.where(verse_id: verse_ids).delete_all
    ChapterInfo.where.not(language_id: 38).delete_all
    Audio::ChapterAudioFile.where("chapter_id > 10").delete_all

    puts "Pruning Pruning topics"
    keep_ids = Topic.limit(50).pluck(:id)
    Topic.where.not(id: keep_ids).delete_all
    ArabicTransliteration.where(verse_id: verse_ids).delete_all
    VerseTopic.where(verse_id: verse_ids).delete_all

    puts "Pruning mushaf data"
    mushafs_to_keep = [1,2,5,6]
    MushafPage.where.not(mushaf_id: mushafs_to_keep).delete_all
    MushafWord.where.not(mushaf_id: mushafs_to_keep).delete_all
    MushafWord.where(verse_id: verse_ids).delete_all
    MushafWord.where(verse_id: verse_ids).delete_all
    MushafWord.where.not(mushaf_id: mushafs_to_keep).delete_all

    NavigationSearchRecord.delete_all
    WordTranslation.where(word_id: word_ids).delete_all
    Word.where(id: word_ids).delete_all

    Chapter.find_each do |chapter|
      chapter.slugs.where.not(locale: 'en').delete_all
      chapter.translated_names.where.not(language_id: 38).delete_all
    end

    ApiClient.delete_all
    ResourceContent.update_all(meta_data: {})
    ApiClientRequestStat.delete_all
    ResourceTag.delete_all
    Tag.delete_all

    DataSource.update_all(name: 'Demo', url: 'Demo', description: 'Demo data source for QUL')
    verses.delete_all

    puts "Creating SQL dump"
    system("pg_dump quran_dev > dumps/mini_quran_dev.sql")

    puts "Creating binary dump"
    system("pg_dump -b -E UTF-8 -f dumps/mini_quran_dev.dump --no-owner --no-privileges --no-tablespaces -F c -Z 9 --clean quran_dev")

    puts "Mini dump created successfully."
  end

  task remove_old_tables: :environment do
    if !Rails.env.development?
      raise "This task can only be run in development environment"
    end

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
      'word_lemma',
      'word_root',
      'word_font',
      'text',
      'ayah',
      'surah',
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
        connection.execute("DROP TABLE IF EXISTS #{t} CASCADE")
      rescue Exception => e
        puts "========= failed to remove table #{t}"
        puts e.message
      end
    end
  end
end