namespace :mushaf do
  task duplicate: :environment do
    mushaf = Mushaf.find(17)
    duplicate = mushaf.dup
    duplicate.name = "#{mushaf.name} (Duplicate of #{mushaf.id})"
    duplicate.save!
    duplicate.mushaf_pages.delete_all

    mushaf.mushaf_pages.each do |page|
      duplicate_page = page.dup
      duplicate_page.mushaf_id = duplicate.id
      duplicate_page.save!
    end

    MushafLineAlignment.where(mushaf_id: mushaf.id).each do |line|
      duplicate_line = line.dup
      duplicate_line.mushaf_id = duplicate.id
      duplicate_line.save!
    end

    MushafWord.where(mushaf_id: mushaf.id).each do |word|
      duplicate_word = word.dup
      duplicate_word.mushaf_id = duplicate.id
      duplicate_word.save!
    end
  end
end