namespace :db do
  desc "Migrate WordLemmas and WordStems to words.lemma_id and words.stem_id"
  task migrate_lemmas_and_stems: :environment do
    # For Lemma
    lemma_updated_count = 0
    lemma_skipped = []

    WordLemma.eager_load(:word).find_each do |word_lemma|
      word = word_lemma.word
      lemma = Lemma.find_by(id: word_lemma.lemma_id)

      if word.nil? || word.lemma_id.present?
        lemma_skipped << word_lemma.id
        next
      end

      if lemma
        word.update_column(:lemma_id, lemma.id)
        lemma_updated_count += 1
      end
    end

    puts "Lemma migration complete! #{lemma_updated_count} words updated with lemma_id."
    puts "Skipped WordLemma IDs: #{lemma_skipped.join(', ')}" unless lemma_skipped.empty?

    # For Lemma
    stem_updated_count = 0
    stem_skipped = []

    WordStem.eager_load(:word).find_each do |word_stem|
      word = word_stem.word
      stem = Stem.find_by(id: word_stem.stem_id)

      if word.nil? || word.stem_id.present?
        stem_skipped << word_stem.id
        next
      end

      if stem
        word.update_column(:stem_id, stem.id)
        stem_updated_count += 1
      end
    end

    puts "Stem migration complete! #{stem_updated_count} words updated with stem_id."
    puts "Skipped WordStem IDs: #{stem_skipped.join(', ')}" unless stem_skipped.empty?

    puts "All migrations completed."
  end
end
