require 'csv'

namespace :subjective_tafsir do
  desc "Import New Content Data"
  task import: :environment do
    rc = ResourceContent.find_or_create_by!(
      slug: 'thematic_commentary_gloss',
      language: Language.find_by!(iso_code: 'ar')
    ) do |r|
      r.name = "مصحف التفصيل الموضوعي مع تفسير كلمات القرآن"
    end

    puts "Clearing old Draft::Content for slug=#{rc.slug}…"
    Draft::Content.where(resource_content_id: rc.id).delete_all
    ActiveRecord::Base.connection.reset_pk_sequence!(Draft::Content.table_name)

    csv_path = Rails.root.join('data','مصحف التفصيل الموضوعي مع تفسير كلمات القرآن.csv')
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

      start_v = Verse.find_by!(chapter_id: surah, verse_number: from_v)

      Draft::Content.create!(
        resource_content_id: rc.id,
        chapter_id:          surah,
        verse_id:            start_v.id,
        location:            "#{surah}:#{from_v}-#{to_v}",
        draft_text:          merged_desc,
        imported:            true,
        need_review:         true,
        text_matched:        false,
        meta_data: {
          source:     "مصحف التفصيل الموضوعي",
          color_code: color_code,
          raw_text:   merged_desc
        }
      )
    end

    puts "Done importing into ResourceContent “#{rc.name}” (ID=#{rc.id})"
  end
end
