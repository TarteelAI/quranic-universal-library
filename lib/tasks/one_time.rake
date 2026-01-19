namespace :one_time do
  desc "Add group translations for 'يا أيها الذين آمنوا' phrase and fix WbW translations"
  task fix_group_translations: :environment do
    phrase_start = "يا ايها الذين امنوا"
    language_id = 38

    verses = Verse.where("text_imlaei_simple LIKE ?", "#{phrase_start}%")

    total_updates = 0
    updates = {}

    verses.find_each do |verse|
      words = verse.words.order(:position).first(3)
      next if words.size < 3

      w1, w2, w3 = words

      translations_map = {
        w1.id => "O you",
        w2.id => "those who(believe)",
        w3.id => "believe"
      }

      translations_map.each do |word_id, fixed_text|
        wt = WordTranslation.where(word_id: word_id, language_id: language_id).first_or_initialize
        updates[wt.word.location] = { old: wt.text, new: fixed_text } if wt.text != fixed_text
        wt.text = fixed_text
        wt.group_word_id = w1.id

        if word_id == w1.id
          wt.group_text = "O you who believe"
        else
          wt.group_text = "*(1)"
        end

        wt.save!
      end
      total_updates += 1
    end
  end

  task update_audio_url: :environment do
    mapping = {
      1 => 'quran/surah/abdul_baset/mujawwad',
      2 => 'quran/surah/abdul_baset/murattal',
      3 => 'quran/surah/abdurrahmaan_as_sudais/murattal',
      4 => 'quran/surah/abu_bakr_shatri/murattal',
      5 => 'quran/surah/hani_ar_rifai/murattal',
      6 => 'quran/surah/khalil_al_husary/muallim',
      7 => 'quran/surah/mishari_al_afasy/murattal',
      8 => 'quran/surah/minshawi/mujawwad',
      9 => 'quran/surah/minshawi/murattal',
      200 => 'quran/surah/minshawi/kids_repeat',
      10 => 'quran/surah/saud_ash_shuraym/murattal',
      12 => 'quran/surah/khalil_al_husary/muallim',
      13 => 'quran/surah/saad_al_ghamdi/murattal',

      65 => 'quran/surah/maher-al-muaiqly_1424_1425/murattal',
      161 => 'quran/surah/khalifa_al_tunaiji/murattal/',
      168 => 'quran/surah/minshawi/kids_repeat',
      164 => 'quran/surah/khalil_al_husary/mujawwad',
      174 => 'quran/surah/yasser_ad-dussary/murattal',
      175 => 'quran/surah/alnufais/murattal',
      179 => 'quran/surah/mansour_al_salimi_1444/murattal',
    }

    mapping.each do |reciter_id, path|
      recitation = Audio::Recitation.find(reciter_id)
      recitation.relative_path = "#{path}/mp3"
      recitation.update_audio_stats
      recitation.save(validate: false)
      recitation.send(:update_related_resources)

      Audio::ChapterAudioFile.where(audio_recitation_id: recitation.id).each do |file|
        file.audio_url = "https://audio-cdn.tarteel.ai/#{path}/mp3/#{file.chapter_id.to_s.rjust(3, '0')}.mp3"
        file.save(validate: false)
        file.update_segment_percentile
      end
    end

    ids = [178, 179, 180, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204]
    ids.each do |id|
      puts "Processing #{id}"
      recitation = Audio::Recitation.find(id)
      recitation.update_audio_stats
      recitation.save(validate: false)
      recitation.send(:update_related_resources)
      Audio::ChapterAudioFile.where(audio_recitation_id: recitation.id).each do |file|
        file.update_segment_percentile
      end
    end
  end

  desc "Compare tashkeel counts between two scripts in Word model"
  task :compare_tashkeel => :environment do
    script_a = 'text_digital_khatt'
    script_b = 'text_digital_khatt_v1'
    regex = /[\u064B-\u065F\u0670\u06D6-\u06ED]/

    def tashkeel_count(text, regex)
      text.to_s.scan(regex).size
    end

    Word.find_each do |word|
      a_text = word.send(script_a)
      b_text = word.send(script_b)

      next if a_text.blank? || b_text.blank?

      a_count = tashkeel_count(a_text, regex)
      b_count = tashkeel_count(b_text, regex)

      if a_count != b_count
        puts "[Word ##{word.id}] #{script_a}=#{a_count}, #{script_b}=#{b_count}"
        puts "  #{script_a}: #{a_text}"
        puts "  #{script_b}: #{b_text}"
      end
    end
  end

  desc "Check for duplicate waqf signs and diacritic issues in Word texts"
  task check_words: :environment do
    waqf_regex = /([\u06D6-\u06ED])\1+/ # duplicate Quranic annotation signs
    diacritic_regex = /([\u064B-\u065F\u0670])\1+/ # duplicate harakat / superscript alef

    attrs = ["text_uthmani",
             "text_indopak",
             "text_imlaei_simple",
             "text_imlaei",
             "text_uthmani_simple",
             "text_uthmani_tajweed",
             "text_qpc_hafs",
             "text_indopak_nastaleeq",
             "text_qpc_nastaleeq",
             "text_qpc_nastaleeq_hafs",
             "text_digital_khatt",
             "text_digital_khatt_v1",
             "text_qpc_hafs_tajweed",
             "text_digital_khatt_indopak"]

    Word.find_each do |word|
      attrs.each do |attr|
        text = word.send(attr)
        next unless text.present?

        issues = []
        issues << "Duplicate waqf signs" if text.match?(waqf_regex)
        issues << "Duplicate diacritics" if text.match?(diacritic_regex)

        if issues.any?
          puts "[Word ##{word.id}] #{attr} => #{issues.join(', ')} | text: #{text}"
        end
      end
    end
  end

  task find_similar_starts: :environment do
    verses = Verse.unscoped.order('verse_index ASC').pluck(:id, :chapter_id, :verse_number, :text_imlaei_simple)

    previous = nil
    matches = []
    verses.each do |id, surah, ayah, text|
      words = text.to_s.split(/\s+/)
      next if words.size < 2

      first_two = words[0, 2].join(" ")

      if previous && previous[:first_two] == first_two && previous[:surah] == surah && previous[:ayah] + 1 == ayah
        puts "Match found in Surah #{surah}: Ayah #{previous[:ayah]} and #{ayah}"
        puts "  -> #{previous[:text]}"
        puts "  -> #{text}"
        puts "-----------------------------------"
        matches << [previous[:surah], previous[:ayah], ayah, first_two]
      end

      previous = { surah: surah, ayah: ayah, first_two: first_two, text: text }
    end
  end

  task fix_segments: :environment do
    AudioFile.find_each do |f|
      if f.segments.present?
        f.set_segments(f.get_segments)
      end
    end
  end

  task import_transliteration: :environment do
    CDN = "PATH_TO_CDN"
    # Turkish transliteration
    FileUtils.mkdir_p "data/transliterations"
    Utils::Downloader.download("#{CDN}/data/transliterations/tajweed_transliteration.json", "data/transliterations/tajweed_transliteration2.json")
    Utils::Downloader.download("#{CDN}/data/transliterations/tr.transliteration.json", "data/transliterations/tr2.transliteration.json")
    PaperTrail.enabled = false

    turkish = Language.where(iso_code: 'tr').first
    resource = ResourceContent.one_verse.where(name: 'Turkish Transliteration').first_or_create
    resource.language = turkish
    resource.language_name = turkish.name.downcase
    resource.save

    tr_data = Oj.load File.read("data/transliterations/tr2.transliteration.json")

    tr_data.each do |row|
      verse = Verse.find_by(chapter_id: row['sura'], verse_number: row['aya'])
      text = row['text'].strip

      tr = Translation.where(
        verse_id: verse.id,
        resource_content_id: resource.id
      ).first_or_initialize

      tr.text = text
      tr.resource_name = resource.name
      tr.verse_key = verse.verse_key
      tr.chapter_id = verse.chapter_id
      tr.verse_number = verse.verse_number
      tr.juz_number = verse.juz_number
      tr.hizb_number = verse.hizb_number
      tr.language_name = 'turkish'
      tr.language = turkish
      tr.save
    end
    resource.run_after_import_hooks

    # Tajweed transliteration
    en = Language.where(iso_code: 'en').first
    en_resource = ResourceContent.one_verse.where(name: 'English Transliteration(Tajweed)').first_or_create
    en_resource.language = en
    en_resource.language_name = en.name.downcase
    en_resource.save

    tajweed_data = Oj.load File.read("data/transliterations/tajweed_transliteration2.json")

    tajweed_data.each do |row|
      verse = Verse.find_by(chapter_id: row['sura'], verse_number: row['aya'])
      text = row['text'].strip

      tr = Translation.where(
        verse_id: verse.id,
        resource_content_id: en_resource.id
      ).first_or_initialize

      tr.text = text
      tr.resource_name = en_resource.name
      tr.verse_key = verse.verse_key
      tr.chapter_id = verse.chapter_id
      tr.verse_number = verse.verse_number
      tr.juz_number = verse.juz_number
      tr.hizb_number = verse.hizb_number
      tr.language_name = 'english'
      tr.language = en
      tr.save
    end
    en_resource.run_after_import_hooks

    # RTF
    rtf_resource = ResourceContent.one_verse.where(name: 'English Transliteration(RTF)').first_or_create
    rtf_resource.language = en
    rtf_resource.language_name = en.name.downcase
    rtf_resource.save

    rtf_data = Oj.load File.read("data/transliterations/en.transliteration.json")

    rtf_data.each do |row|
      verse = Verse.find_by(chapter_id: row['sura'], verse_number: row['aya'])
      text = row['text'].strip

      tr = Translation.where(
        verse_id: verse.id,
        resource_content_id: rtf_resource.id
      ).first_or_initialize

      tr.text = text
      tr.resource_name = rtf_resource.name
      tr.verse_key = verse.verse_key
      tr.chapter_id = verse.chapter_id
      tr.verse_number = verse.verse_number
      tr.juz_number = verse.juz_number
      tr.hizb_number = verse.hizb_number
      tr.language_name = 'english'
      tr.language = en
      tr.save
    end
  end

  task find_missing_svg: :environment do
    missing = []
    related = {}
    Word.find_each do |word|
      surah, ayah, word_number = word.location.split(':')
      next if word.ayah_mark?
      next if File.exist?("scripts/img/svg-tajweed/#{surah}/#{ayah}/#{word_number}.svg")

      puts "#{word.location} is missing"
      missing << word.location
    end

    Word.where(location: missing).each do |word|
      similar = Word.where(text_qpc_hafs: word.text_qpc_hafs)

      found = similar.detect do |w|
        surah, ayah, word_number = w.location.split(':')
        w if File.exist?("scripts/img/svg-tajweed/#{surah}/#{ayah}/#{word_number}.svg")
      end

      if found
        related[word.location] = found.location
      end
    end
  end

  task find_missing_images: :environment do
    require 'net/http'
    require 'uri'

    CDN_BASE = "PATH_TO_CDN"

    Word.find_each do |word|
      surah, ayah, word_number = word.location.split(':')
      next if Dir.exist?("scripts/img/available/#{surah}/#{ayah}/#{word_number}")

      puts "checking #{word.location}"

      if word.ayah_mark?
        url = URI("#{CDN_BASE}/common/#{ayah}.svg")
      else
        svg_path = "w/svg-tajweed/#{surah}/#{ayah}/#{word_number}.svg"
        url = URI("#{CDN_BASE}/#{svg_path}")
      end

      response = Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == "https") do |http|
        http.head(url.request_uri)
      end

      if response.code == "404"
        puts "Missing SVG: #{word.location}"

        if !word.ayah_mark?
          begin
            source = "scripts/img/svg-tajweed/#{surah}/#{ayah}/#{word_number}.svg"
            FileUtils.mkdir_p("scripts/img/svg-missing/#{surah}/#{ayah}")
            missing_path = "scripts/img/svg-missing/#{surah}/#{ayah}/#{word_number}.svg"
            FileUtils.cp source, missing_path
          rescue Errno::ENOENT => e
            puts "Error copying file for #{word.location}: #{e.message}"
          end
        end
      else
        FileUtils.mkdir_p("scripts/img/available/#{surah}/#{ayah}/#{word_number}")
      end
    end
  end

  task preview_tafsir_app: :Environment do
    data = Oj.load File.read("data/tafsir-app-sample.json")

    def export(data)
      res = "<html>
<head>
    <meta charset='utf-8'>
    <style>
        .poetry{
            text-align: center;
            color: orange;
        }
        .ar{
            direction: rtl;
        } .hlt{
            color: red;
        }.ayah-tag{color:blue}
    </style>
</head>
<body>
<div class=ar land=ar>
  #{simple_format data['data']}
</div>
</body>
</html>
"
      File.open("data/res.html", "wb") do |f|
        f.puts res
      end
    end
  end

  task import_segments: :environment do
    recitation = Recitation.where(id: 42).first_or_create(reciter_name: 'Test')

    def load_segments(verse)
      file = "../quran-segment-align/timestamps/alnafes/#{verse.chapter_id.to_s.rjust(3, '0')}#{verse.verse_number.to_s.rjust(3, '0')}.json"
      if File.exist?(file)
        data = Oj.load File.read(file)

        i = 0
        data.map do |a|
          i += 1
          start = if i == 1
                    0
                  else
                    a['start'].to_f * 1000.0
                  end

          [i, start, a['end'].to_f * 1000.0]
        end
      else
        []
      end
    end

    Verse.order('verse_index asc').find_each do |v|
      audio_file = AudioFile.where(
        recitation_id: recitation.id,
        verse_id: v.id
      ).first_or_initialize
      audio_file.chapter_id = v.chapter_id
      audio_file.hizb_number = v.hizb_number
      audio_file.juz_number = v.juz_number
      audio_file.manzil_number = v.manzil_number
      audio_file.verse_number = v.verse_number
      audio_file.page_number = v.page_number
      audio_file.rub_el_hizb_number = v.rub_el_hizb_number
      audio_file.ruku_number = v.ruku_number
      audio_file.verse_key = v.verse_key

      audio_file.format = 'mp3'
      audio_file.is_enabled = true
      url = "http://audio-cdn.tarteel.ai/quran/alnafes/#{v.chapter_id.to_s.rjust(3, '0')}#{v.verse_number.to_s.rjust(3, '0')}.mp3"
      audio_file.url = url
      audio_file.segments = load_segments(v)
      audio_file.save(validate: false)
    end

    Recitation.find_each do |r|
      r.update_audio_stats
    end
  end

  task generate_align_text: :environment do
    FileUtils.mkdir_p "dataset/text"

    Dir["../quran-segment-align/dataset/audio/Alnafes_wav/*.wav"].each do |file|
      name = File.basename(file, ".wav")
      FileUtils.rm(file) if name[3..5] == '000'
    end

    missing = []
    exist = []
    Verse.find_each do |v|
      if File.exist?("../quran-segment-align/dataset/audio/Alnafes_wav/#{v.chapter_id.to_s.rjust(3, '0')}#{v.verse_number.to_s.rjust(3, '0')}.wav")
        exist << v.verse_key
      else
        missing << v.verse_key
      end
    end

    Verse.find_each do |v|
      name = "#{v.chapter_id.to_s.rjust(3, '0')}#{v.verse_number.to_s.rjust(3, '0')}"
      File.open("dataset/text/#{name}.txt", "wb") do |f|
        f.puts v.text_uthmani
      end
    end
  end

  task update_lines_count: :environment do
    MushafPage.find_each do |page|
      page.update_lines_count
    end
  end

  task remove_space_before_footnote: :environment do
    PaperTrail.enabled = false

    Translation.where("text LIKE '% <%'").find_each do |t|
      t.text = t.text.gsub(/\s</, '<')
      t.save
    end
  end

  task update_footnote_count: :environment do
    draft_translations = Draft::Translation.joins(:foot_notes).distinct
    draft_translations.each do |t|
      t.update_column :footnotes_count, t.foot_notes.size
    end

    translations = Translation.joins(:foot_notes).distinct

    translations.each do |t|
      t.update_column :footnotes_count, t.foot_notes.size
    end
  end

  task create_resource_tags: :environment do
    DownloadableResource.find_each do |resource|
      tags = resource.tags.to_s.split(',').map do |t|
        t.strip.humanize
      end
      tags.each do |name|
        tag = DownloadableResourceTag.where(name: name).first_or_create

        DownloadableResourceTagging.where(
          downloadable_resource_id: resource.id,
          downloadable_resource_tag_id: tag.id
        ).first_or_create
      end
    end
  end

  task import_phrases: :environment do
    phrases = CSV.read("#{Rails.root}/tmp/phrases.csv", headers: true)
    phrases_ayahs = CSV.read("#{Rails.root}/tmp/phrases_verses.csv", headers: true)
    Utils::Downloader.download("https://static-cdn.tarteel.ai/qul/data/phrases.csv", "tmp/phrases.csv")
    Utils::Downloader.download("https://static-cdn.tarteel.ai/qul/data/phrases_verses.csv", "tmp/phrases_verses.csv")

    Morphology::PhraseVerse.update_all(approved: false)
    Morphology::Phrase.update_all(approved: false)

    phrases.each do |p|
      phrase = Morphology::Phrase.where(id: p['id']).first_or_initialize
      phrase.attributes = p.to_hash
      phrase.save
    end

    phrases_ayahs.each do |p|
      phrase = Morphology::PhraseVerse.where(id: p['id']).first_or_initialize
      phrase.attributes = p.to_hash
      phrase.save
    end

    Morphology::Phrase.where(words_count: 1).count

    Morphology::PhraseVerse.where(missing_word_positions: "[]").update_all missing_word_positions: []
  end

  task fix_timestamp: :environment do
    def replace(source, fixed)
      source.segments = fixed.segments
      source.save
    end

    verse = Verse.find_by(verse_key: '28:38')
    source_recitation = 18
    fixed_recitation = 7

    replace(
      AudioFile.where(recitation_id: source_recitation, verse_id: verse.id).first,
      AudioFile.where(recitation_id: fixed_recitation, verse_id: verse.id).first
    )
  end

  task fix_line_alignment: :environment do
    mushaf_v2 = Mushaf.find(1)

    pages = MushafLineAlignment
              .where(mushaf_id: mushaf_v2.id, alignment: 'surah_name')
              .order('page_number ASC, line_number ASC')
    s = 1

    pages.map do |p|
      p.get_surah_number
    end.uniq.size

    pages.map do |p|
      [p.page_number, p.get_surah_number]
    end

    pages.each do |p|
      p.properties['surah_number'] = s
      s += 1
      p.save
    end
  end

  desc "Create morphology graphs and word nodes for verses without graph data"
  task create_missing_graphs: :environment do
    empty_graphs = Morphology::DependencyGraph::Graph
                     .left_joins(:nodes)
                     .where(morphology_dependency_graph_nodes: { id: nil })
    count = empty_graphs.count

    if count.positive?
      deleted = empty_graphs.delete_all
      puts "Deleted #{deleted} empty graphs."
    end

    existing_verse_keys = Morphology::DependencyGraph::Graph.distinct.pluck(:chapter_number, :verse_number).map do |chapter_number, verse_number|
      "#{chapter_number}:#{verse_number}"
    end.to_set

    puts "Found #{existing_verse_keys.size} verses with existing graphs"

    verses_with_morphology = Verse
                               .joins(:morphology_words)
                               .includes(:morphology_words)
                               .distinct
                               .select(:id, :chapter_id, :verse_number, :verse_key)

    verses_to_process = verses_with_morphology.reject do |verse|
      existing_verse_keys.include?("#{verse.chapter_id}:#{verse.verse_number}")
    end

    total = verses_to_process.size
    puts "Found #{total} verses with morphology words but no graphs"

    if total == 0
      puts "Nothing to do. All verses with morphology data already have graphs."
      next
    end

    created_graphs = 0
    created_nodes = 0
    errors = []

    verses_to_process.each_with_index do |verse, index|
      morphology_words = Morphology::Word
                           .includes(:word, :word_segments)
                           .where(verse_id: verse.id)
                           .joins(:word)
                           .order('words.position ASC')

      next if morphology_words.empty?

      begin
        ActiveRecord::Base.transaction do
          graph = Morphology::DependencyGraph::Graph.create!(
            chapter_number: verse.chapter_id,
            verse_number: verse.verse_number,
            graph_number: 1
          )
          created_graphs += 1

          node_index = 0
          morphology_words.each do |morphology_word|
            morphology_word.word_segments.each do |segment|
              Morphology::DependencyGraph::GraphNode.create!(
                graph_id: graph.id,
                type: 'word',
                number: node_index,
                segment_id: segment.id,
                resource_type: 'Morphology::Word',
                resource_id: morphology_word.id
              )
              node_index += 1
            end
            created_nodes += node_index
          end
        end
      rescue StandardError => e
        errors << { verse_key: verse.verse_key, error: e.message }
        puts "Error processing verse #{verse.verse_key}: #{e.message}"
      end

      if (index + 1) % 100 == 0 || index + 1 == total
        puts "Progress: #{index + 1}/#{total} verses processed (#{created_graphs} graphs, #{created_nodes} nodes created)"
      end
    end

    puts "\n=== Summary ==="
    puts "Total graphs created: #{created_graphs}"
    puts "Total nodes created: #{created_nodes}"

    if errors.any?
      puts "\nErrors (#{errors.size}):"
      errors.each { |e| puts "  - #{e[:verse_key]}: #{e[:error]}" }
    end

    puts "\nDone!"
  end
end