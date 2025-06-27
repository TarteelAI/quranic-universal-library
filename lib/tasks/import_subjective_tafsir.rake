require 'roo'

namespace :subjective_tafsir do
  desc "Import Subjective Tafsir from the Excel file"
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

    xlsx_path = Rails.root.join("data/مصحف التفصيل الموضوعي مع تفسير كلمات القرآن.xlsx")
    xlsx      = Roo::Excelx.new(xlsx_path)
    headers   = xlsx.row(1).map(&:to_s)

    puts "→ Importing #{xlsx.last_row - 1} rows…"
    (2..xlsx.last_row).each do |i|
      row         = Hash[headers.zip(xlsx.row(i))]
      surah       = row["Surah"].to_i
      from_verse  = row["From"].to_i
      to_verse    = row["To"].to_i
      desc        = row["Description"].to_s.strip
      color_code  = row["Color"].to_s.strip

      start_v = Verse.find_by!(chapter_id: surah, verse_number: from_verse)
      end_v   = Verse.find_by!(chapter_id: surah, verse_number: to_verse)

      Draft::Content.create!(
        resource_content_id: rc.id,
        chapter_id:          surah,
        verse_id:            start_v.id,
        location:            "#{surah}:#{from_verse}–#{to_verse}",
        draft_text:          desc,
        imported:            true,
        need_review:         true,
        text_matched:        false,
        meta_data: {
          source:     "مصحف التفصيل الموضوعي",
          color_code: color_code,
          raw_text:   desc
        }
      )
    end

    puts "Done importing into ResourceContent “#{rc.name}” (ID=#{rc.id})"
  end
end
