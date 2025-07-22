require 'json'

namespace :import_asbab do
  desc "Import Asbab Al-Nuzul Tafsir from JSON data"
  task english: :environment do
    resource = ResourceContent.find_or_create_by!(
      name: "Wahidi Asbāb‑us‑Nuzūl",
      language: Language.find_by!(iso_code: 'en'),
      author_name: "Al-Wahidi",
      resource_type: 'tafsir',
      cardinality_type: '1_ayah',
      slug: 'asbab_al_nuzul_al_wahidi',
      language_name: 'english'
    )

    Draft::Tafsir.where(resource_content_id: resource.id).delete_all
    ActiveRecord::Base.connection.reset_pk_sequence!(Draft::Tafsir.table_name)

    json_data = JSON.parse(File.read('data/asbab_nazul_english.json'))

    total_groups      = 0
    individual_verses = 0
    missing_tafsirs   = 0

    ActiveRecord::Base.transaction do
      json_data.each do |verse_key, tafsir_text|
        html_tafsir = tafsir_text
                        .split(/\r?\n/)
                        .map(&:strip)
                        .reject(&:empty?)
                        .map { |para| "<p>#{para}</p>" }
                        .join("\n")

        surah_num, verse_range = verse_key.split(':')
        start_verse, end_verse = if verse_range.include?('-')
                                   verse_range.split('-').map(&:to_i)
                                 else
                                   [verse_range.to_i, verse_range.to_i]
                                 end

        if tafsir_text.include?("No tafsir for this verse exists") && (start_verse != end_verse)
          (start_verse..end_verse).each do |verse_num|
            create_tafsir_record(
              resource: resource,
              surah_num: surah_num,
              verse_num: verse_num,
              tafsir_text: html_tafsir
            )
            individual_verses += 1
            missing_tafsirs   += 1
          end
          total_groups += 1
          next
        end

        create_tafsir_record(
          resource: resource,
          surah_num: surah_num,
          start_verse: start_verse,
          end_verse: end_verse,
          tafsir_text: html_tafsir
        )

        total_groups    += 1
        missing_tafsirs += 1 if tafsir_text.include?("No tafsir for this verse exists")
      end
    end

    puts "\nImport completed!"
    puts "Total groups processed: #{total_groups}"
    puts "Individual verses created: #{individual_verses}"
    puts "Tafsirs with missing content: #{missing_tafsirs}"
  end

  private

  def create_tafsir_record(resource:, surah_num:, verse_num: nil, start_verse: nil, end_verse: nil, tafsir_text:)
    start_verse ||= verse_num
    end_verse   ||= verse_num

    start_ayah = Verse.find_by!(chapter_id: surah_num, verse_number: start_verse)
    end_ayah   = Verse.find_by!(chapter_id: surah_num, verse_number: end_verse)

    Draft::Tafsir.create!(
      resource_content_id: resource.id,
      verse_id: start_ayah.id,
      start_verse_id: start_ayah.id,
      end_verse_id: end_ayah.id,
      group_verse_key_from: "#{surah_num}:#{start_verse}",
      group_verse_key_to:   "#{surah_num}:#{end_verse}",
      group_verses_count:   (end_verse - start_verse + 1),
      group_tafsir_id:      start_ayah.id,
      draft_text:           tafsir_text,
      current_text:         nil,
      imported:             true,
      text_matched:         false,
      need_review:          true,
      meta_data: {
        source:        'greattafsirs.com',
        tafsir_type:   'asbab_al_nuzul',
        original_key:  "#{surah_num}:#{start_verse}-#{end_verse}"
      }
    )
  rescue ActiveRecord::RecordNotFound => e
    puts "Error: Verse not found - Surah #{surah_num}:#{start_verse}-#{end_verse}: #{e.message}"
  end
end
