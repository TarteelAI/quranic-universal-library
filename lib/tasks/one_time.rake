namespace :one_time do
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

  task add_sequence_number_to_words: :environment do
    sequence_number = 1
    Word.unscoped.order('word_index ASC').each do |word|
      if word.word?
        word.update_column :sequence_number, sequence_number
        sequence_number += 1
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
end