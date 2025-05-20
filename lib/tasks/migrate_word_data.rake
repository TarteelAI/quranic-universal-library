namespace :db do
  desc "Migrate WordLemma and WordStem associations into words"
  task migrate_lemmas_and_stems: :environment do
    lemma_updated = 0
    lemma_skipped = 0

    WordLemma.includes(:word).find_each do |wl|
      w = wl.word
      next unless w && w.lemma_id.nil?

      if (lem = Lemma.find_by(id: wl.lemma_id))
        w.update_column(:lemma_id, lem.id)
        lemma_updated += 1
      else
        lemma_skipped += 1
      end
    end

    stem_updated = 0
    stem_skipped = 0

    WordStem.includes(:word).find_each do |ws|
      w = ws.word
      next unless w && w.stem_id.nil?

      if (st = Stem.find_by(id: ws.stem_id))
        w.update_column(:stem_id, st.id)
        stem_updated += 1
      else
        stem_skipped += 1
      end
    end

    puts "Lemma updated: #{lemma_updated}, skipped: #{lemma_skipped}"
    puts "Stem  updated: #{stem_updated}, skipped: #{stem_skipped}"
  end
end
