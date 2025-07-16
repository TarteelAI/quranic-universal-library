namespace :quran_script do
  desc "Import Warsh ayah by ayah script"
  task import_warsh_ayah: :environment do
    rc = ResourceContent.find_or_create_by!(
      slug:     "warsh-script",
      language: Language.find_by!(iso_code: "ar")
    ) do |r|
      r.name             = "Quran Script(Warsh)"
      r.sub_type         = ResourceContent::SubType::QuranText
      r.cardinality_type = ResourceContent::CardinalityType::OneVerse
    end
    warsh = QiratType.find_or_create_by!(name: "Warsh")

    QuranScript::ByVerse.where(
      resource_content_id: rc.id,
      qirat_id:            warsh.id
    ).delete_all

    path  = Rails.root.join("tmp",  "UthmanicWarshV21.docx.txt")
    whole = File.read(path, encoding: "utf-8")
    total = 0

    whole.split(/^سُورَةُ/).reject(&:blank?).each_with_index do |chunk, i|
      chapter_id = i + 1
      lines      = chunk.lines.map(&:strip).reject { |l|
        l.blank? || l.include?("بِسْمِ اِ۬للَّهِ اِ۬لرَّحْمَٰنِ") || l =~ /^_{2,}$/
      }
      lines.shift
      text = lines.join(" ")

      text.scan(/(.+?)[\s ]+([\u0660-\u0669]+)/) do |frag, num|
        verse_num = num.chars.map { |c| c.ord - 0x0660 }.join.to_i
        verse     = Verse.find_by(chapter_id: chapter_id, verse_number: verse_num)
        next unless verse

        QuranScript::ByVerse.create!(
          resource_content_id: rc.id,
          qirat_id:            warsh.id,
          chapter_id:          chapter_id,
          verse_number:        verse_num,
          text:                frag.strip,
          key:                 "#{chapter_id}:#{verse_num}"
        )
        total += 1
      end

      expected = Verse.where(chapter_id: chapter_id).pluck(:verse_number)
      imported = QuranScript::ByVerse.where(
        resource_content_id: rc.id,
        qirat_id:            warsh.id,
        chapter_id:          chapter_id
      ).pluck(:verse_number)
      (expected - imported).each do |v|
        Rails.logger.warn "skipped verse #{chapter_id}:#{v}"
      end
    end

    puts "Imported verses: #{total}"
  end

######################### import_warsh_by_words #################################
  desc "Import Uthmanic Warsh V21 into quran_script_by_words"
  task import_warsh_by_words: :environment do
    rc = ResourceContent.find_or_create_by!(
      slug:     "warsh-script-wbw",
      language: Language.find_by!(iso_code: "ar")
    ) do |r|
      r.name             = "Quran Script(Warsh) WBW"
      r.sub_type         = ResourceContent::SubType::QuranText
      r.cardinality_type = ResourceContent::CardinalityType::OneWord
    end
    warsh = QiratType.find_by!(name: "Warsh")

    QuranScript::ByWord.where(
      resource_content_id: rc.id,
      qirat_id:            warsh.id
    ).delete_all

    path  = Rails.root.join("tmp",  "UthmanicWarshV21.docx.txt")
    whole      = File.read(path, encoding: "utf-8")
    total_words = 0

    whole.split(/^سُورَةُ/).reject(&:blank?).each_with_index do |chunk, i|
      chapter_id = i + 1
      lines      = chunk.lines.map(&:strip).reject { |l|
        l.blank? || l.include?("بِسْمِ") || l =~ /^_{2,}$/
      }
      lines.shift
      text = lines.join(" ")

      text.scan(/(.+?)[\s ]+([\u0660-\u0669]+)/) do |verse_text, num|
        verse_num = num.chars.map { |c| c.ord - 0x0660 }.join.to_i
        verse     = Verse.find_by(chapter_id: chapter_id, verse_number: verse_num)
        next unless verse

        tokens     = verse_text.strip.split(/[[:space:]\u00A0]+/)
        words_db   = Word.where(verse_id: verse.id).order(:position).to_a

        tokens.each_with_index do |tok, idx|
          w = words_db[idx]
          next unless w

          QuranScript::ByWord.create!(
            resource_content_id: rc.id,
            qirat_id:            warsh.id,
            chapter_id:          chapter_id,
            verse_id:            verse.id,
            verse_number:        verse_num,
            word_id:             w.id,
            word_number:         idx + 1,
            text:                tok.strip,
            key:                 "#{chapter_id}:#{verse_num}:#{idx + 1}"
          )
          total_words += 1
        end
      end
    end

    puts "Imported words: #{total_words}"
  end
end
