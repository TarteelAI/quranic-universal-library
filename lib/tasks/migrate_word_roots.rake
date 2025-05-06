namespace :db do
  desc "Migrate WordRoots to words.root_id"
  task migrate_roots: :environment do
    updated_count = 0
    root_skipped = []

    WordRoot.eager_load(:word).find_each do |word_root|
      word = word_root.word
      root = Root.find_by(id: word_root.root_id)

      if word.nil? || word.root_id.present?
        root_skipped << word_root.id
        next
      end

      if root
        word.update_column(:root_id, root.id)
        updated_count += 1
      end
    end

    puts "Data migration complete! #{updated_count} words updated with root_id."
    puts "Skipped WordRoot IDs: #{root_skipped.join(', ')}"
  end
end
