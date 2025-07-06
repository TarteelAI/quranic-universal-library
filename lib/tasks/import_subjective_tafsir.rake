require 'csv'

namespace :subjective_tafsir do
  desc "Import New Content Data"
  task import: :environment do
    Utils::Downloader.download("CND/data/topics.csv", "tmp/topics.csv")
    Utils::Downloader.download("CND/data/topic-colors.csv", "tmp/topic-colors.csv")

    language = Language.find_by!(iso_code: 'ar')
    topic_colors = CSV.read(Rails.root.join('tmp', 'topic-colors.csv'), headers: true)
    colors_map = {}

    topic_colors.each do |row|
      color = row['Number'].to_s.strip
      name = row['Color'].to_s.strip
      code_code = "rgb(#{row['Dark']})"
      theme = row['Theme'].to_s.strip
      description_ar = row['Details (ar)'].to_s.strip
      description_en = row['Details (en)'].to_s.strip

      colors_map[color] = {
        color_name: name,
        color_code: code_code,
        theme: theme,
        description_ar: description_ar,
        description_en: description_en
      }
    end

    rc = ResourceContent.find_or_create_by!(
      slug: 'thematic-ayah-topics-arabic',
      language: language,
      name: 'Thematic topics of Ayah',
    )
    rc.sub_type = 'theme'
    rc.cardinality_type = 'n_ayah'
    rc.set_meta_value("archive-embed-url", "https://archive.org/embed/quran-with-color-by-subject")
    rc.set_meta_value("source", "https://archive.org/details/quran-with-color-by-subject/page/n5/mode/2up")
    rc.set_meta_value("theme-colors", colors_map)

    rc.save
    rc.translated_names.where(
      language: language,
      name: "مصحف التفصيل الموضوعي مع تفسير كلمات القرآن"
    ).first_or_create

    Draft::Content.where(resource_content_id: rc.id).delete_all
    ActiveRecord::Base.connection.reset_pk_sequence!(Draft::Content.table_name)

    csv_path = Rails.root.join('tmp', 'topics.csv')


    unless File.exist?(csv_path)
      puts "CSV file not found at #{csv_path}. Please export your Excel sheet as CSV to this path."
      exit 1
    end

    rows = CSV.read(csv_path, headers: true).map(&:to_h)
    puts "→ Read #{rows.size} rows from CSV…"

    grouped = rows.group_by { |row| [row['Surah'].to_i, row['From'].to_i, row['To'].to_i] }

    puts "Processing #{grouped.size} unique verse ranges…"

    grouped.each do |(surah, from_v, to_v), entries|
      merged_desc = entries.map { |r| "<p>#{r['Description'].to_s.strip}</p>" }.join("\n")
      color_code  = entries.first['Color'].to_s.strip

      start_from = Verse.find_by!(chapter_id: surah, verse_number: from_v)
      start_to = Verse.find_by!(chapter_id: surah, verse_number: to_v)

      Draft::Content.create!(
        resource_content_id: rc.id,
        chapter_id:          surah,
        verse_id:            start_from.id,
        location:            "#{start_from.verse_key} - #{start_to.verse_key}",
        draft_text:          merged_desc,
        imported:            false,
        need_review:         false,
        text_matched:        false,
        meta_data: {
          verse_from: start_from.verse_key,
          verse_to:   start_to.verse_key,
          color_number: color_code,
          color: colors_map[color_code][:color_code],
          raw_text:   entries
        }
      )
    end

    puts "Done importing into ResourceContent “#{rc.name}” (ID=#{rc.id})"
  end
end
