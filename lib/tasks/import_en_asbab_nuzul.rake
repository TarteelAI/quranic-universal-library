namespace :import_asbab do
  desc "Import Asbab Al-Nuzul Tafsir from JSON data"
  task import_english: :environment do
    require 'json'
    resource = ResourceContent.find_or_create_by!(
      name: "Wahidi Asbab‑us‑Nuzul",
      language: Language.find_by!(iso_code: 'en'),
      author_name: "Al-Wahidi",
      resource_type: 'tafsir',
      cardinality_type: '1_ayah',
      slug: 'asbab-alnuzul-al-wahidi',
      language_name: 'english'
    )

    Draft::Tafsir.where(resource_content_id: resource.id).delete_all
    ActiveRecord::Base.connection.reset_pk_sequence!(Draft::Tafsir.table_name)

    json_data = JSON.parse(File.read('tmp/asbab_nazul_english.json'))

    total_groups = 0
    individual_verses = 0
    missing_tafsirs = 0

    json_data.each do |verse_key, tafsir_text|
      next if tafsir_text.include?("No tafsir for this verse exists")

      html_tafsir = tafsir_text
                      .split(/\r?\n/)
                      .map(&:strip)
                      .reject(&:empty?)
                      .map { |para| "<p>#{para}</p>" }
                      .join("")

      surah_num, verse_range = verse_key.split(':')
      start_verse, end_verse = if verse_range.include?('-')
                                 verse_range.split('-').map(&:to_i)
                               else
                                 [verse_range.to_i, verse_range.to_i]
                               end

      create_tafsir_record(
        resource: resource,
        surah_num: surah_num,
        start_verse: start_verse,
        end_verse: end_verse,
        tafsir_text: html_tafsir,
        text: tafsir_text
      )
    end

    resource.reload.run_draft_import_hooks

    puts "\nImport completed!"
    puts "Total groups processed: #{total_groups}"
    puts "Individual verses created: #{individual_verses}"
    puts "Tafsirs with missing content: #{missing_tafsirs}"
  end

  private

  def create_tafsir_record(resource:, surah_num:, start_verse:, end_verse:, tafsir_text:, text:)
    start_verse = Verse.find_by!(chapter_id: surah_num, verse_number: start_verse)
    end_verse = Verse.find_by!(chapter_id: surah_num, verse_number: end_verse)

    Draft::Tafsir.create!(
      resource_content_id: resource.id,
      verse_id: start_verse.id,
      start_verse_id: start_verse.id,
      end_verse_id: end_verse.id,
      group_verse_key_from: start_verse.verse_key,
      group_verse_key_to: end_verse.verse_key,
      group_verses_count: (end_verse.id - start_verse.id + 1),
      group_tafsir_id: start_verse.id,
      draft_text: tafsir_text,
      imported: false,
      text_matched: false,
      need_review: true,
      meta_data: {
        text: text,
        range: "#{surah_num}:#{start_verse.verse_number}-#{end_verse.verse_number}"
      }
    )
  end
end
