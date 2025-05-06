namespace :db do
  desc "Migrate WordRoots to words.root_id"
  task migrate_roots: :environment do
    updated_count = 0

    WordRoot.find_each do |word_root|
      word = Word.find_by(id: word_root.word_id)
      root = Root.find_by(id: word_root.root_id)

      next unless word && root

      if word.update(root_id: root.id)
        updated_count += 1
      end
    end

    puts "Data migration complete! #{updated_count} words updated with root_id."
  end
end