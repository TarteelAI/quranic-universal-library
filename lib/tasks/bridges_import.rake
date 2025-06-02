namespace :bridges do
  desc "Import Bridges’ translations into Draft::Translation"
  task import: :environment do
    file = Rails.root.join("data/bridges_quran.json")
    raw  = JSON.parse(File.read(file))

    resource          = ResourceContent.find_by!(name: "Fadel Soliman, Bridges’ translation")
    footnote_resource = ResourceContent.find_by!(name: "Bridges’ translation footnotes")

    Draft::Translation.where(resource_content_id: resource.id).delete_all
    Draft::FootNote.where(resource_content_id: footnote_resource.id).delete_all

    ActiveRecord::Base.connection.reset_pk_sequence!(Draft::Translation.table_name)
    ActiveRecord::Base.connection.reset_pk_sequence!(Draft::FootNote.table_name)

    created_count = 0

    def process_text(text, surah_fns)
      counter = 0
      aya_fns = []

      processed = text.gsub(/<a\s+([^>]+)>(.*?)<\/a>/i) do
        attrs, content = Regexp.last_match(1), Regexp.last_match(2)
        href = attrs[/href\s*=\s*['"](__FN\d+__|sg|pl|dl)['"]/, 1]&.strip
        cls  = attrs[/class\s*=\s*['"]([^'"]+)['"]/, 1]

        if href&.match?(/sg|pl|dl/i) && cls&.include?('superscript')
          %Q(<sup>#{content}</sup>)
        elsif cls&.include?('fn_qiraat') && href
          fn_id    = href.delete("_")
          counter += 1
          fn_text  = surah_fns["__#{fn_id}__"]
          full_text = %Q(<span class="qiraat-footnote">Qira’at: #{fn_text}</span>)
          aya_fns << { placeholder: "__FN_PLACEHOLDER_#{counter}__", original_id: fn_id, text: full_text, type: "qirat" }
          %Q(<span class="h">#{content}<sup foot_note="__FN_PLACEHOLDER_#{counter}__">#{counter}</sup></span>)
        elsif href&.start_with?('__FN') && cls&.include?('fn_regular')
          fn_id    = href.delete("_")
          counter += 1
          regular_text = surah_fns["__#{fn_id}__"]
          aya_fns << { placeholder: "__FN_PLACEHOLDER_#{counter}__", original_id: fn_id, text: regular_text, type: "regular" }
          %Q(#{content}<sup foot_note="__FN_PLACEHOLDER_#{counter}__">#{counter}</sup>)
        else
          content
        end
      end

      # Clean up spacing around tags and punctuation
      cleaned = processed
                  .gsub(/<\/span>\s+/, '</span>')
                  .gsub(/\s+(<span)/, ' \1')
                  .gsub(/(\d)(<\/sup>)(?=\w)/, '\1\2 ')
                  .gsub(/(\w)(<sup foot_note="\d+">\d+<\/sup>)(?=\w)/, '\1\2 ')
                  .gsub(/(\w)(<sup foot_note="pl">pl<\/sup>)/, '\1 \2')
                  .gsub(/(\w)(<sup foot_note="sg">sg<\/sup>)/, '\1 \2')
                  .gsub(/(\w)(<sup foot_note="dl">dl<\/sup>)/, '\1 \2')
                  .gsub(/(\d)<sup foot_note=/, '\1 <sup foot_note=')
                  .gsub(/<\/sup><\/span>(?=[\w,])/, '</sup></span> ')
                  .gsub(/\s+,/, ',')

      [cleaned, aya_fns]
    end

    raw.each do |_, surah_data|
      next unless surah_data.is_a?(Hash) && surah_data["groups"]

      surah_id  = surah_data["surah_id"].to_i
      surah_fns = surah_data["footnotes"] || {}

      surah_data["groups"].each do |group|
        group["ayas"].each do |ayah|
          verse_number = ayah["id"].to_i
          verse = Verse.find_by(chapter_id: surah_id, verse_number: verse_number)
          next unless verse

          processed_text, fns = process_text(ayah["text"].to_s, surah_fns)

          original = Translation.find_by(resource_content_id: resource.id, verse_id: verse.id)
          source_text = original&.text || ''

          dt = Draft::Translation.create!(
            verse_id:            verse.id,
            resource_content_id: resource.id,
            draft_text:          processed_text,
            current_text:        source_text,
            text_matched:        (source_text == processed_text),
            imported:            false,
            meta_data: {
              "source-data" => {
                "sura"           => surah_id.to_s,
                "aya"            => verse_number.to_s,
                "arabic_text"    => ayah["arabic"].to_s,
                "resource_text"  => ayah["text"].to_s,
                "footnotes"      => fns.each_with_object({}) { |fn, h| h[fn[:placeholder]] = fn[:text] }
              }
            }
          )

          fns.each do |fn|
            foot = Draft::FootNote.create!(
              draft_translation_id: dt.id,
              resource_content_id:  footnote_resource.id,
              draft_text:           fn[:text],
              current_text:         fn[:text],
              text_matched:         true,
              foot_note_id:         fn[:original_id].to_i
            )
            dt.draft_text = dt.draft_text.gsub(fn[:placeholder], foot.id.to_s)
          end

          dt.save!
          created_count += 1
        end
      end
    end

    puts "Imported #{created_count} Draft::Translation records."
  end
end
