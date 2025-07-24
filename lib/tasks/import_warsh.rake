namespace :quran_script do
  desc "Import Warsh ayah by ayah script"
  task import_warsh_ayah: :environment do
    rc = ResourceContent.find_or_create_by!(
      slug:     "qpc-warsh-script-ayah",
      language: Language.find_by!(iso_code: "ar")
    ) do |r|
      r.name             = "Quran Script(Warsh) - Ayah by Ayah"
      r.sub_type         = ResourceContent::SubType::QuranText
      r.cardinality_type = ResourceContent::CardinalityType::OneVerse
    end

    warsh = QiratType.find_or_create_by!(name: "Warsh")

    path = Rails.root.join("tmp", "UthmanicWarshV21.json")
    file = File.read(path, encoding: "utf-8")
    data = JSON.parse(file)
    total = 0
    imported_verses = {}

    data["pages"].each do |page|
      page["surahs"].each do |surah|
        chapter_id = surah["chapter"]
        imported_verses[chapter_id] ||= []

        surah["verses"].each do |verse|
          verse_key = verse["verse_key"]
          _, verse_number = verse_key.split(":").map(&:to_i)

          QuranScript::ByVerse.create!(
            resource_content_id: rc.id,
            qirat_id:            warsh.id,
            chapter_id:          chapter_id,
            verse_number:        verse_number,
            text:                verse["text"].strip,
            key:                 verse_key
          )

          total += 1
          imported_verses[chapter_id] << verse_number
        end
      end
    end

    (1..114).each do |chapter_id|
      expected = QuranScript::ByVerse.where(chapter_id: chapter_id).pluck(:verse_number).uniq.sort
      imported = imported_verses[chapter_id] || []
      missing = expected - imported
      missing.each { |v| puts "WARNING: Missing verse #{chapter_id}:#{v}" }
    end

    puts "Imported #{total} verses"
  end

  desc "Import Uthmanic Warsh V21 into quran_script_by_words"
  task import_warsh_by_words: :environment do
    rc = ResourceContent.find_or_create_by!(
      slug: "qpc-warsh-script-wbw",
      language: Language.find_by!(iso_code: "ar")
    ) do |r|
      r.name             = "Quran Script(Warsh) - Word by Word"
      r.sub_type         = ResourceContent::SubType::QuranText
      r.cardinality_type = ResourceContent::CardinalityType::OneWord
    end

    warsh = QiratType.find_by!(name: "Warsh")

    path = Rails.root.join("tmp", "UthmanicWarshV21.json")
    file = File.read(path, encoding: "utf-8")
    data = JSON.parse(file)
    total_words = 0

    verse_key_map = QuranScript::ByVerse.where(qirat: warsh).pluck(:key, :id).to_h

    data["pages"].each do |page|
      page["surahs"].each do |surah|
        chapter_id = surah["chapter"]

        surah["verses"].each do |verse|
          verse_key = verse["verse_key"]

          unless verse_key_map.key?(verse_key)
            puts "WARNING: Verse not found #{verse_key}"
            next
          end

          verse_id = verse_key_map[verse_key]
          _, verse_number = verse_key.split(":").map(&:to_i)

          verse["words"].each do |word_data|
            word_key = word_data["key"]
            word_text = word_data["text"].strip
            _, _, word_position = word_key.split(":").map(&:to_i)

            QuranScript::ByWord.create!(
              resource_content_id: rc.id,
              qirat_id:            warsh.id,
              chapter_id:          chapter_id,
              verse_number:        verse_number,
              word_number:         word_position,
              text:                word_text,
              key:                 word_key
            )
            total_words += 1
          end
        end
      end
    end

    puts "Imported #{total_words} words"
  end
end
