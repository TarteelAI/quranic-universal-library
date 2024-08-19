namespace :dump do
  desc "Create mini dump"
  task create: :environment do
    if !Rails.env.development?
      raise "This task can only be run in development environment"
    end

    PaperTrail.enabled = false
    verses = Verse.where("verse_number > 20")
    Morphology::DerivedWord.delete_all
    Audio::Segment.where("verse_id IN(?)", verses.pluck(:id)).delete_all
    Morphology::Word.where("verse_id IN(?)", verses.pluck(:id)).delete_all
    Translation.where("verse_number > 20").delete_all
    Morphology::WordSegment.delete_all
    Morphology::WordVerbForm.delete_all
    Morphology::Phrase.delete_all
    Morphology::PhraseVerse.delete_all

    Audio::ChangeLog.delete_all
    AudioFile.where("verse_id IN(?)", verses.pluck(:id)).delete_all
    ChapterInfo.where.not(language_id: 38).delete_all

    ArabicTransliteration.where("verse_id IN(?)", verses.pluck(:id)).delete_all
    AyahTheme.delete_all
    TopicVerse.delete_all
    Topic.delete_all
    WordStem.delete_all
    WordLemma.delete_all
    WordRoot.delete_all

    Word.joins("LEFT JOIN verses ON verses.id = words.verse_id")
               .where(verses: { id: nil })
               .delete_all

    NavigationSearchRecord.delete_all
    WordTranslation.where("verse_id IN (?)", verses.pluck(:id)).delete_all
    Word.where("verse_id IN(?)", verses.pluck(:id)).delete_all
    verses.delete_all

    Chapter.find_each do |chapter|
      chapter.slugs.where.not(locale: 'en').delete_all
      chapter.translated_names.where.not(language_id: 38).delete_all
    end
  end
end