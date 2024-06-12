namespace :corpus do
=begin
  Dir["data/positions/*.json"].each do |file|
    data = JSON.parse(File.read(file))
    data.each do |location, data|
      WordTajweedPosition.create(location: location, positions: data)
    end
  end
=end

  #TODO:
  # Arabic Grammar
  # https://ultimatearabic.com/mubtada-and-khabar/#khabar
  # https://hinative.com/en-US/questions/15290876
  # https://corpus.quran.com/documentation/particlealif.jsp
  # https://rse-i.blogspot.com/2021/05/concordance-labeling-of-quranic-words-and-aayaat.html
  # https://qurancore.com/dictionary/%D8%B3%D9%85%D9%88
  # http://www.rootwordsofquran.com/
  # http://qurancode.com/
  # https://qurananalysis.com/explore/?lang=EN
  # https://qurandev.github.io/widgets/
  # https://qurandev.github.io/widgets/datastore.html?synonyms=1
  task import_csvs: :environment do
    def import_csv(filename, model)
      content = open("corpus-export/#{filename}").read

      CSV.parse(content, headers: true).each do |row|
        record = model.where(id: row['id']).first_or_initialize
        record.attributes = row.to_h.except('id')
        record.save(validate: false)
        puts record.id
      end
    end

    import_csv "words.csv", Morphology::Word
    import_csv "segments.csv", Morphology::WordSegment
    import_csv "derived_words.csv", Morphology::DerivedWord
    import_csv "verb_forms.csv", Morphology::WordVerbForm
  end

  task export_csv: :environment do
    def export_to_csv(filename, model)
      CSV.open("corpus-export/#{filename}", "wb") do |csv|
        csv << model.attribute_names
        model.order('id asc').each do |record|
          csv << record.attributes.values
        end
      end
    end

    FileUtils.mkdir_p("corpus-export")

    export_to_csv "words.csv", Morphology::Word
    export_to_csv "segments.csv", Morphology::WordSegment
    export_to_csv "derived_words.csv", Morphology::DerivedWord
    export_to_csv "verb_forms.csv", Morphology::WordVerbForm
  end

  task parse_quran_corpus: :environment do
    def detect_pos_segment(word, pos, index)
      segment = word.word_segments.detect do |seg|
        seg.has_pos_feature?(pos) && seg.position > index
      end

      return segment if segment

      segment = word.word_segments.first_or_initialize(hidden: true, part_of_speech_key: pos, position: word.word_segments.order("position ASC").last.position)
      segment.add_feature(pos)
      segment
    end

    Verse.order("verse_index ASC").each do |verse|
      verse.words.each do |word|
        next unless word.word?
        morphology_word = word.morphology_word
        data = File.read("data/words-data/corpus-data/word-corpus-html/#{verse.verse_key.tr(':', '/')}/#{word.position}.html")
        parsed_html = Nokogiri.parse(data)

        desc_node = parsed_html.search(".contentCell form p:nth-child(1)").first
        description = desc_node.children.to_s.strip
        morphology_word.update_column(:description, description)

        nodes = parsed_html.search(".morphologyCell").children.select do |c|
          c.text.present? || c.name == 'br'
        end

        arabicNodes = parsed_html.search(".grammarCell").children.select do |c|
          c.text.present?
        end

        puts morphology_word.location

        groups = []
        group = []

        nodes.each do |node|
          if node.name == 'br'
            groups.push group
            group = []
          else
            group.push node
          end
        end
        groups.push group

        position = -1
        hidden_segment = nil
        groups.each_with_index do |group, index|
          pos = group.detect do |seg|
            seg.name == 'b'
          end&.text

          topic = group.detect do |seg|
            seg.name == 'a'
          end

          english_grammar = group.map do |seg|
            if !['b', 'a'].include?(seg.name)
              seg.to_s.strip.gsub(/–|→/, '')
            end
          end.compact_blank.join('').strip.humanize

          if english_grammar.casecmp('Implicit subject pronoun').zero?
            hidden_segment = morphology_word.word_segments.where(part_of_speech_key: pos, grammar_term_desc_english: 'Implicit subject pronoun').first_or_initialize
            hidden_segment.hidden = true
            hidden_segment.position = morphology_word.word_segments.order('position ASC').last.position
            hidden_segment.add_feature(pos)
            hidden_segment.save(validate: false)
          end

          segment = hidden_segment || detect_pos_segment(morphology_word, pos, position)
          position = segment.position
          segment.grammar_term_desc_english = english_grammar
          segment.grammar_term_desc_arabic = arabicNodes[index].to_s

          if topic.present?
            segment.topic = Topic.where(name: topic.text.to_s).first_or_create
          end

          segment.save
        end
      end
    end
  end

  task parse_wbw_corpus_data: :environment do
    Morphology::DerivedWord.delete_all

    Verse.find_each do |verse|
      data = JSON.parse(File.read("data/words-data/corpus-data/quranwbw-api/#{verse.chapter_id}/#{verse.verse_number}.json"))

      data = data[verse.chapter_id.to_s][verse.verse_number.to_s]['words']

      data.each_with_index do |corpus, i|
        word = verse.words.where(position: i + 1).first
        morphology_word = word.morphology_word
        puts word.location

        # segment grammar
        verbs = corpus['word_corpus']['verbs'].compact_blank
        root = corpus['word_corpus']['root']
        derived_forms = root['derived_forms'] || []

        grammar = corpus['word_corpus']['grammar']

        verbs_map = {}
        if verbs.present?
          verbs.each_pair do |form, val|
            word_form = morphology_word.verb_forms.where(name: form).first_or_initialize
            word_form.value = val
            word_form.save

            verbs_map[val] = word_form.id
          end
        end

        derived_forms.each do |derived|
          form = derived['form']
          words = derived['derived_words']
          words.each do |w|
            morphology_word.derived_words.create(
              form_name: form,
              en_translation: w['translation'],
              en_transliteration: w['transliteration'],
              verse_id: Verse.find_by(verse_key: w['location']).id,
              word_verb_from_id: verbs_map[form]
            )
          end
        end

        grammar.each_with_index do |g, index|
          puts "#{word.location}:#{index + 1}"

          next if g['type'].blank? && g['segment'].blank?

          if part = morphology_word.word_segments.where(position: index + 1).first
            part.update(part_of_speech_name: g['type']) if g['type'].present?
          else
            part = morphology_word.word_segments.build(
              part_of_speech_key: 'FIXME',
              part_of_speech_name: g['type'],
              lemma_name: '',
              position: index + 1,
              root_name: '',
              text_uthmani: g['segment']
            )

            part.save(validate: false)
          end
        end
      end
    end
  end

  task parse_morphology_file: :environment do
    class CorpusLine
      ROOT_REG = /ROOT:(?<value>[^|]*)/
      LEMMA_REG = /LEM:(?<value>[^|]*)/
      VERB_FROM_REG = /VF:(?<value>[^|]*)/

      attr_reader :line, :location

      def initialize(line)
        @line = line.strip.split("\t")
        @location = @line[0].split(':')
      end

      def arabic
        line[1].to_s.strip
      end

      def pos_tags
        line[3].sub(LEMMA_REG, '').sub(ROOT_REG, '').strip.split('|').compact_blank
      end

      def lemma
        match = line[3].match(LEMMA_REG)

        if match
          match['value'].to_s.strip
        end
      end

      def root
        match = line[3].match(ROOT_REG)

        if match
          match['value'].to_s.strip
        end
      end

      def verb_form
        match = line[3].match(VERB_FROM_REG)

        if match
          match['value'].to_s.strip
        end
      end

      def part_of_speech_key
        line[2].to_s.strip
      end

      def chapter_id
        location[0].to_s.strip
      end

      def verse_number
        location[1].to_s.strip
      end

      def word_number
        location[2].to_s.strip
      end

      def word_part_position
        location[3].to_s.strip
      end
    end

    IO.foreach("data/quran-morphology.txt") do |line|
      corpus_line = CorpusLine.new(line)
      verse = Verse.where(chapter_id: corpus_line.chapter_id, verse_number: corpus_line.verse_number).first
      word = verse.words.where(position: corpus_line.word_number).first
      puts word.location
      morphology_word = Morphology::Word.where(word_id: word.id).first_or_initialize

      if morphology_word.new_record?
        # make sure morphology word has same id as word.
        # This is important and will be very useful later on.
        morphology_word.id = word.id
        morphology_word.verse_id = word.verse_id
        morphology_word.location = word.location
        morphology_word.words_count_for_lemma = word.lemma.word_lemmas.size if word.lemma
        morphology_word.words_count_for_root = word.root.word_roots.size if word.root
        morphology_word.words_count_for_stem = word.stem.word_stems.size if word.stem
      end

      morphology_word.save(validate: false)

      part = morphology_word.word_segments.where(position: corpus_line.word_part_position).first_or_initialize
      part.text_uthmani = corpus_line.arabic
      part.verb_form = corpus_line.verb_form
      part.root_name = corpus_line.root
      part.lemma_name = corpus_line.lemma
      part.part_of_speech_key = corpus_line.part_of_speech_key
      part.pos_tags = corpus_line.pos_tags.join(',')

      part.save(validate: false)
    end
  end

  task import_morphology_terms: :environment do
    # TODO: import this page as well https://corpus.quran.com/documentation/tagset.jsp
    url = "https://raw.githubusercontent.com/mustafa0x/quran-morphology/master/morphology-terms-ar.json"
    response = with_rescue_retry([RestClient::Exceptions::ReadTimeout], retries: 3, raise_exception_on_limit: true) do
      RestClient.get(url)
    end

    data = JSON.parse(response.body)

    data.keys.each do |category|
      terms = data[category]
      if terms.is_a? Hash
        terms.each_pair do |term_key, arabic|
          term = Corpus::MorphologyTerm.new(category: category, term: term_key)
          term.arabic_grammar_name = arabic
          term.save
        end
      end
    end
  end

  task prepare_recitequran_imgs: :environment do
    # word: https://audio.recitequran.com/wbw/arabic/wisam_sharieff/00032.mp3
    # tajweed: https://audio.recitequran.com/tajweed/wisam_sharieff/00025.mp3

    words_audio = {}

    1.upto(668) do |page|
      data = File.read("data/words-data/corpus-data/recitequran/#{page}.json")
      data = JSON.parse data.gsub("(", '').gsub(");", "")

      data['Verses'].each do |html|
        docs = Nokogiri::HTML::DocumentFragment.parse(html)
        offset = 0
        previous_ayah = nil

        docs.children.each_with_index do |child, pos|
          surah = child.attr('s')
          ayah = child.attr('a')
          audio = child.attr('f')

          if ['qhzb', 'sajdah'].include? child.attr('class').to_s
            offset += 1
            next
          end

          tajweed = if (t = child.search(".b").first)
                      t.attr("f")
                    end

          if ayah == '0'
            # skip bismillah
            next
          end

          pos = pos - offset + 1
          location = "#{surah}:#{ayah}:#{pos}"

          #word = Word.where(location: "#{surah}:#{ayah}:#{pos}").first
          #words_audio[word.id] = { w: audio, t: tajweed }.compact_blank
          #img_data = child.search("img").attr("src").value.split("data:image/jpeg;base64,")[1]
          #FileUtils.mkdir_p "data/words-data/corpus-data/images/w/rq-color/#{surah}/#{ayah}/"
          #if word.ayah_mark?
          # File.open "data/words-data/corpus-data/images/w/ayah-number/#{word.verse.verse_number}.png", "wb" do |f|
          #  f.write Base64.decode64 img_data
          #end
          #else
          #  File.open "data/words-data/corpus-data/images/w/rq-color/#{surah}/#{ayah}/#{pos}.png", "wb" do |f|
          #    f.write Base64.decode64 img_data
          #  end
          #end
        end
      end
    end

    File.open "data/words-data/corpus-data/images/recite-quran-audio.json", "wb" do |f|
      f.puts words_audio.to_json
    end

    sajdah_words = ["53:62:3",
                    "17:109:5",
                    "96:19:5",
                    "84:21:6",
                    "16:50:7",
                    "27:26:8",
                    "22:77:11",
                    "13:15:11",
                    "7:206:11",
                    "41:38:12",
                    "25:60:13",
                    "32:15:15",
                    "19:58:29",
                    "38:24:32",
                    "22:18:37"]

    hizb_words = "29:26:1, 26:52:1, 12:101:1, 7:156:1, 76:19:1, 5:82:1, 2:26:1, 7:31:1, 33:60:1, 18:75:1, 36:28:1, 49:14:1, 16:90:1, 9:19:1, 29:46:1, 9:34:1, 3:93:1, 40:21:1, 21:29:1, 37:83:1, 2:44:1, 9:93:1, 39:53:1, 12:7:1, 9:122:1, 28:12:1, 2:75:1, 27:56:1, 12:77:1, 2:92:1, 9:60:1, 13:19:1, 44:17:1, 2:124:1, 43:24:1, 42:51:1, 3:133:1, 33:51:1, 14:10:1, 25:53:1, 6:74:1, 42:27:1, 26:111:1, 34:10:1, 6:127:1, 25:21:1, 4:100:1, 34:24:1, 47:33:1, 7:117:1, 41:47:1, 3:15:1, 7:171:1, 3:153:1, 19:59:1, 5:97:1, 10:71:1, 4:58:1, 11:24:1, 11:108:1, 36:60:1, 46:21:1, 41:25:1, 20:111:1, 33:18:1, 12:53:1, 13:5:1, 5:27:1, 3:113:1, 40:66:1, 7:47:1, 59:11:1, 7:65:1, 7:142:1, 35:41:1, 8:61:1, 17:50:1, 6:13:1, 2:158:1, 3:186:1, 2:253:1, 2:272:1, 4:24:1, 4:74:1, 10:11:1, 4:163:1, 10:90:1, 35:15:1, 2:203:1, 5:51:1, 2:243:1, 18:32:1, 11:84:1, 8:41:1, 20:83:1, 23:75:1, 51:31:1, 5:12:1, 7:88:1, 28:76:1, 50:27:1, 14:28:1, 3:171:1, 2:106:1, 11:61:1, 37:145:1, 60:7:1, 3:75:1, 21:51:1, 16:75:1, 16:51:1, 4:114:1, 9:111:1, 10:26:1, 10:53:1, 58:14:1, 16:30:1, 16:111:1, 18:17:1, 18:51:1, 37:22:1, 3:33:1, 38:52:1, 11:41:1, 13:35:1, 30:31:1, 26:181:1, 22:19:1, 22:38:1, 32:11:1, 34:46:1, 42:13:1, 54:9:1, 31:22:1, 27:82:1, 21:83:1, 4:88:1, 6:151:1, 24:21:1, 43:57:1, 4:135:1, 6:111:1, 20:55:1, 17:99:1, 56:75:1, 2:283:1, 47:10:1, 4:12:1, 27:27:1, 2:177:1, 39:32:1, 15:49:1, 2:189:1, 12:30:1, 38:21:1, 45:12:1, 6:59:1, 28:51:1, 6:36:1, 6:141:1, 52:24:1, 9:46:1, 2:60:1, 40:41:1, 53:26:1, 11:6:1, 39:8:1, 57:16:1, 41:9:1, 4:36:
1, 4:148:1, 8:22:1, 19:22:1, 28:29:1, 63:4:1, 17:70:1, 17:23:1, 33:3
1:1, 2:142:1, 22:60:1, 2:233:1, 48:18:1, 30:54:1, 24:53:1, 18:99:1,
2:219:1, 73:20:1, 70:19:1, 24:35:1, 2:263:1, 5:41:1, 5:67:1, 6:95:1,
 5:109:1, 3:52:1, 7:189:1, 9:75:1, 23:36:1, 100:9:1"
  end

  task tajweed_pos_recitequran_imgs: :environment do
    def parse_styles(style_string)
      style_mapping style_string.
        to_s.
        split(';').
        reject { |s| s.strip.empty? }.
        map { |s| parse_style_props(s) }.
        reject { |s| s.nil? }
    end

    def parse_style_props(property_string)
      parts = property_string.split(':', 2)
      return nil if parts.nil?
      return nil if parts.length != 2
      return nil if parts.any? { |s| s.nil? }

      { :key => parts[0].strip.downcase, :value => parts[1].strip.downcase }
    end

    def style_mapping(properties)
      properties.reduce({}) do |accum, property|
        accum[property[:key]] = property[:value]
        accum
      end
    end

    words_positions = {}

    1.upto(668) do |page|
      data = File.read("../community-data/words-data/corpus-data/recitequran-clean/#{page}.json")
      data = JSON.parse(data)
      verses = []

      data['Verses'].each do |html|
        docs = Nokogiri::HTML::DocumentFragment.parse(html)
        offset = 0

        docs.children.each_with_index do |child, pos|
          surah = child.attr('s')
          ayah = child.attr('a')
          audio = child.attr('f')

          if ayah == '0'
            # skip bismillah
            next
          end

          if ['qhzb', 'sajdah'].include? child.attr('class').to_s
            offset += 1
            next
          end

          parts = child.search(".img .b")

          pos = pos - offset + 1
          word = Word.where(location: "#{surah}:#{ayah}:#{pos}").first
          child.set_attribute('loc', word.location)
        end
        verses << docs.to_html
      end

      data['Verses'] = verses

      File.open("data/recitequran.com/recitequran-clean/#{page}.json", "wb") do |file|
        file.puts data.to_json
      end
    end

    words_positions.each do |location, data|
      WordTajweedPosition.create location: location, positions: data
    end

    File.open "data/words-data/corpus-data/recite-quran-positions.json", "wb" do |f|
      f.puts words_positions.to_json
    end
  end

  task download_recite_quran_audio: :environment do
    # word: https://audio.recitequran.com/wbw/arabic/wisam_sharieff/00032.mp3
    # tajweed: https://audio.recitequran.com/tajweed/wisam_sharieff/00025.mp3

    require 'typhoeus'
    hydra = Typhoeus::Hydra.new

    data = JSON.parse File.read("data/words-data/corpus-data/recite-quran-audio.json")

    tajweed_audio = {}
    word_audio = {}

    data.each do |id, mapping|
      if mapping.present?
        word = Word.find(id)

        if word.word?
          next if File.exist?("data/words-data/corpus-data/images/wbw/#{word.verse_key.gsub(":", "/")}/#{word.position}.mp3")
          FileUtils.mkdir_p("data/words-data/corpus-data/images/wbw/#{word.verse_key.gsub(":", "/")}")

          if mapping["w"]
            url = "https://audio.recitequran.com/wbw/arabic/wisam_sharieff/#{mapping["w"]}"

            request = Typhoeus::Request.new(url)
            hydra.queue(request)
            hydra.run

            File.open("data/words-data/corpus-data/images/wbw/#{word.verse_key.gsub(":", "/")}/#{word.position}.mp3", "wb") do |file|
              file.write request.response.body
            end
            word_audio[mapping["w"]] = true
          end

          if false && mapping["t"] && tajweed_audio[mapping["t"]].nil?
            url = "https://audio.recitequran.com/tajweed/wisam_sharieff/#{mapping["t"]}"
            request = Typhoeus::Request.new(url)
            hydra.queue(request)
            hydra.run

            File.open("data/words-data/corpus-data/images/wbw/#{word.verse_key.gsub(":", "/")}/#{word.position}-#{word.position + 1}.mp3", "wb") do |file|
              file.write request.response.body
            end

            tajweed_audio[mapping["t"]] = true
          end
        end
      end
    end
  end

  task cleanup_recitequran_imgs: :environment do
    FileUtils.mkdir_p("data/words-data/corpus-data/recitequran-clean")

    def fix_encoding(text)
      if text.valid_encoding?
        text
      else
        text.scrub
      end.to_s
         .strip
    end

    1.upto(668) do |page|
      data = File.read("data/words-data/corpus-data/recitequran/#{page}.json")
      data = JSON.parse data.gsub("(", '').gsub(");", "")
      data.delete('Translations')

      data['Verses'].each_with_index do |html, index|
        docs = Nokogiri::HTML::DocumentFragment.parse(html)

        docs.children.each_with_index do |child, pos|
          img = child.search("img")[0]
          img.remove_attribute('src')
        end

        data['Verses'][index] = fix_encoding(docs.to_s)
      end

      File.open("data/words-data/corpus-data/recitequran-clean/#{page}.json", "wb") do |file|
        file.puts data.as_json.to_s.gsub("=>", ":").gsub('\"', "'")
      end
    end

    sajdah_words = ["53:62:3",
                    "17:109:5",
                    "96:19:5",
                    "84:21:6",
                    "16:50:7",
                    "27:26:8",
                    "22:77:11",
                    "13:15:11",
                    "7:206:11",
                    "41:38:12",
                    "25:60:13",
                    "32:15:15",
                    "19:58:29",
                    "38:24:32",
                    "22:18:37"]

    hizb_words = "29:26:1, 26:52:1, 12:101:1, 7:156:1, 76:19:1, 5:82:1, 2:26:1, 7:31:1, 33:60:1, 18:75:1, 36:28:1, 49:14:1, 16:90:1, 9:19:1, 29:46:1, 9:34:1, 3:93:1, 40:21:1, 21:29:1, 37:83:1, 2:44:1, 9:93:1, 39:53:1, 12:7:1, 9:122:1, 28:12:1, 2:75:1, 27:56:1, 12:77:1, 2:92:1, 9:60:1, 13:19:1, 44:17:1, 2:124:1, 43:24:1, 42:51:1, 3:133:1, 33:51:1, 14:10:1, 25:53:1, 6:74:1, 42:27:1, 26:111:1, 34:10:1, 6:127:1, 25:21:1, 4:100:1, 34:24:1, 47:33:1, 7:117:1, 41:47:1, 3:15:1, 7:171:1, 3:153:1, 19:59:1, 5:97:1, 10:71:1, 4:58:1, 11:24:1, 11:108:1, 36:60:1, 46:21:1, 41:25:1, 20:111:1, 33:18:1, 12:53:1, 13:5:1, 5:27:1, 3:113:1, 40:66:1, 7:47:1, 59:11:1, 7:65:1, 7:142:1, 35:41:1, 8:61:1, 17:50:1, 6:13:1, 2:158:1, 3:186:1, 2:253:1, 2:272:1, 4:24:1, 4:74:1, 10:11:1, 4:163:1, 10:90:1, 35:15:1, 2:203:1, 5:51:1, 2:243:1, 18:32:1, 11:84:1, 8:41:1, 20:83:1, 23:75:1, 51:31:1, 5:12:1, 7:88:1, 28:76:1, 50:27:1, 14:28:1, 3:171:1, 2:106:1, 11:61:1, 37:145:1, 60:7:1, 3:75:1, 21:51:1, 16:75:1, 16:51:1, 4:114:1, 9:111:1, 10:26:1, 10:53:1, 58:14:1, 16:30:1, 16:111:1, 18:17:1, 18:51:1, 37:22:1, 3:33:1, 38:52:1, 11:41:1, 13:35:1, 30:31:1, 26:181:1, 22:19:1, 22:38:1, 32:11:1, 34:46:1, 42:13:1, 54:9:1, 31:22:1, 27:82:1, 21:83:1, 4:88:1, 6:151:1, 24:21:1, 43:57:1, 4:135:1, 6:111:1, 20:55:1, 17:99:1, 56:75:1, 2:283:1, 47:10:1, 4:12:1, 27:27:1, 2:177:1, 39:32:1, 15:49:1, 2:189:1, 12:30:1, 38:21:1, 45:12:1, 6:59:1, 28:51:1, 6:36:1, 6:141:1, 52:24:1, 9:46:1, 2:60:1, 40:41:1, 53:26:1, 11:6:1, 39:8:1, 57:16:1, 41:9:1, 4:36:
1, 4:148:1, 8:22:1, 19:22:1, 28:29:1, 63:4:1, 17:70:1, 17:23:1, 33:3
1:1, 2:142:1, 22:60:1, 2:233:1, 48:18:1, 30:54:1, 24:53:1, 18:99:1,
2:219:1, 73:20:1, 70:19:1, 24:35:1, 2:263:1, 5:41:1, 5:67:1, 6:95:1,
 5:109:1, 3:52:1, 7:189:1, 9:75:1, 23:36:1, 100:9:1"
  end


  task export_word_tajweed_rule: :environment do
    words_positions = {}

    def clear_array(array)
      new_array = []
      previous = nil

      array.each do |value|
        new_array << value if value != previous
        previous = value
      end

      new_array
    end

    1.upto(668) do |page|
      data = File.read("../community-data/words-data/corpus-data/recitequran-clean/#{page}.json")
      data = JSON.parse(data)

      data['Verses'].each do |html|
        docs = Nokogiri::HTML::DocumentFragment.parse(html)
        offset = 0

        docs.children.each_with_index do |child, pos|
          surah = child.attr('s')
          ayah = child.attr('a')
          audio = child.attr('f')

          if ayah == '0'
            # skip bismillah
            next
          end

          if ['qhzb', 'sajdah'].include? child.attr('class').to_s
            offset += 1
            next
          end

          parts = child.search(".img .b")
          pos = pos - offset + 1
          location = "#{surah}:#{ayah}:#{pos}"
          word_rules = []

          parts.each do |rule|
            word_rules << rule.attr('rl')
          end

          if word_rules.present?
          words_positions[location] = clear_array(word_rules)
          end
        end
      end
    end

    File.open("../community-data/words-data/corpus-data/word_tajweed_position.json", "wb") do |file|
      file.puts words_positions.as_json.to_s.gsub("=>", ":").gsub('\"', "'")
    end
  end
end

