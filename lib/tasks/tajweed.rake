namespace :tajweed do
  task create_tajweed_words: :environment do
    TAJWEED_RULES = TajweedRules::TAJWEED_RULES

    def parse_tajweed_rules(text)
      doc = Nokogiri::HTML::DocumentFragment.parse(text)

      word_letters = []
      index = 0

      doc.children.each do |children|
        if children.name == 'rule'
          rule = TAJWEED_RULES[children.attr('class').strip]

          children.text.each_char do |char|
            word_letters << {
              c: char,
              r: rule,
              i: index
            }
            index += 1
          end
        else
          children.text.each_char do |char|
            word_letters << {
              i: index,
              c: char
            }
            index += 1
          end
        end
      end

      word_letters
    end

    resource = ResourceContent.quran_script.where(name: "QPC Tajweed New").first_or_create
    resource.sub_type = 'quran-script'
    resource.cardinality_type = '1_word'
    resource.set_meta_value('font', 'qpc-hafs')
    resource.set_meta_value('text_type', 'text_qpc_hafs_tajweed')
    resource.save

    m = Mushaf.find(16)
    mushaf = Mushaf.where(name: "QPC Tajweed New").first_or_create
    mushaf.attributes = m.attributes.except('id', 'name', 'created_at')
    mushaf.resource_content = resource
    mushaf.save

    resource.set_meta_value('mushaf', mushaf.id)
    resource.save

    words = Word.unscoped.order('word_index asc').in_batches(of: 1000)
    words.each do |batch|
      batch.each do |word|
        puts word.location

        tajweed_word = TajweedWord.where(
          word_id: word.id,
          mushaf_id: mushaf.id,
          verse_id: word.verse_id,
          resource_content_id: resource.id
        ).first_or_create

        tajweed_word.letters = parse_tajweed_rules(word.text_uthmani_tajweed)
        tajweed_word.location = word.location
        tajweed_word.position = word.position
        tajweed_word.save
      end
    end
  end

  task parse_rules_index: :environment do
    tajweed_rules = {
      "ham_wasl" => 1,
      "laam_shamsiyah" => 2,
      "madda_normal" => 3,
      "madda_permissible" => 4,
      "madda_necessary" => 5,
      "idgham_wo_ghunnah" => 6,
      "slnt" => 7,
      "ghunnah" => 8,
      "qalaqah" => 9,
      "ikhafa" => 10,
      "madda_obligatory_monfasel" => 11,
      "madda_obligatory_mottasel" => 12,
      "idgham_ghunnah" => 13,
      "ikhafa_shafawi" => 14,
      "idgham_shafawi" => 15,
      "idgham_mutajanisayn" => 16,
      "idgham_mutaqaribayn" => 17,
      "iqlab" => 18,
    }

    rules = {}

    Word.unscoped.words.order('word_index asc').each do |w|
      doc = Nokogiri::HTML::DocumentFragment.parse(w.text_uthmani_tajweed)
      next if doc.search("rule").blank?

      puts w.location
      word_rules = {}
      index = 0
      doc.children.each do |children|
        if children.name == 'rule'
          rule_name = children.attr('class').strip

          character_with_rule = children.text.chars
          character_with_rule.each_with_index do |char, char_index|
            if char.ord == 1600 && character_with_rule[char_index]&.ord == 1648
              # 1600 is tatweel, 1648 is dagger alif
              # We're exporting tajweed rules indexes for DigitalKhatt script, that don't have tatweel after short vowel(dagger alif)
            else
              word_rules[index] = tajweed_rules[rule_name]
              index += 1
            end
          end
        else
          index += children.text.length
        end
      end

      rules[w.location] = word_rules if word_rules.present?
    end

    File.open("rules-new.json", "wb") do |f|
      f.write(rules.to_json)
    end
  end

  task parse_rule_list: :environment do
    RULES_LIST = {}
    Word.unscoped.words.order('word_index asc').each do |w|
      doc = Nokogiri::HTML::DocumentFragment.parse(w.text_uthmani_tajweed)
      next if doc.search("rule").blank?

      puts w.location
      doc.children.each do |children|
        if children.name == 'rule'
          RULES_LIST[children.attr('class').strip] ||= 0
          RULES_LIST[children.attr('class').strip] += 1
        end
      end
    end
  end

  task export_old_tajweed_data_to_json: :environment do
    data = {}
    data_clean = {}
    data_only_tajweed = {}
    data_only_tajweed_letters = {}

    TajweedWord.order('verse_id ASC, position asc').each do |word|
      data[word.location] = {
        text: word.text,
        letters: word.letters
      }

      data_clean[word.location] = word.letters

      if word.has_tajweed_rule?
        data_only_tajweed[word.location] = word.letters
        data_only_tajweed_letters[word.location] = word.letters.select do |s|
          s['r']
        end
      end
    end

    File.open("tajweed-words/words.json", "wb") do |f|
      f.puts data.to_json
    end

    File.open("tajweed-words/words_without_text.json", "wb") do |f|
      f.puts data_clean.to_json
    end

    File.open("tajweed-words/words_with_tajweed.json", "wb") do |f|
      f.puts data_only_tajweed.to_json
    end

    File.open("tajweed-words/words_with_letters_with_a_rule.json", "wb") do |f|
      f.puts data_only_tajweed_letters.to_json
    end
  end

  task create_new_tajweed_data: :environment do
    tajweed_annotation = TajweedAnnotation::Service.new
    mushaf = Mushaf.where(name: "Tajweed New(Auto annotation)").first_or_create
    mushaf.pages_count = 604
    mushaf.qirat_type_id = 1
    mushaf.lines_per_page = 15
    mushaf.save

    Verse.find_each do |v|
      words = tajweed_annotation.add_annotation_on_verse(v)

      words.each do |location, letters|
        w = Word.find_by(location: location)
        tajweed_word = TajweedWord.where(
          word_id: w.id,
          verse_id: v.id
        ).first_or_initialize
        tajweed_word.letters = letters
        tajweed_word.location = location
        tajweed_word.position = w.position
        tajweed_word.mushaf_id = mushaf.id

        begin
          tajweed_word.save(validate: false)
        rescue Exception => e
          puts e.message
          binding.pry
        end
      end
    end
  end
end