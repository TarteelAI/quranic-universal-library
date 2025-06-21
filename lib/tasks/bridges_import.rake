namespace :bridges do
  desc "Import Bridges’ translations into Draft::Translation"
  task import: :environment do
    Utils::Downloader.download("URL", Rails.root.join("tms/bridges_quran-updated2.json"))
    file = Rails.root.join("tms/bridges_quran-updated2.json")
    raw  = JSON.parse(File.read(file))

    resource          = ResourceContent.find(149)
    footnote_resource = ResourceContent.find(150)

    Draft::Translation.where(resource_content_id: resource.id).delete_all
    Draft::FootNote.where(resource_content_id: footnote_resource.id).delete_all

    ActiveRecord::Base.connection.reset_pk_sequence!(Draft::Translation.table_name)
    ActiveRecord::Base.connection.reset_pk_sequence!(Draft::FootNote.table_name)

    created_count = 0

    def fix_formatting(text)
      text.gsub!(%r{<span class="h">(.*?)<sup(.*?)</sup>(.*?)</span>}) do
        before = $1.strip
        sup = "<sup#{$2}</sup>"
        after = $3.strip
        result = []
        result << "<span class=h>#{before}</span>" unless before.empty?
        result << sup
        result << "<span class=h>#{after}</span>" unless after.empty?
        result.join(' ')
      end

      text
    end

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
          full_text = %Q(<span class="qiraat">Qira’at:</span> #{fn_text})
          aya_fns << {
            placeholder: "__FN_PLACEHOLDER_#{counter}__",
            original_id: fn_id,
            text: full_text,
            type: "qirat"
          }
          %Q(<span class="h">#{content}<sup foot_note=__FN_PLACEHOLDER_#{counter}__>#{counter}</sup></span>)
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

          need_review = original.text != processed_text

          dt = Draft::Translation.create!(
            verse_id:            verse.id,
            resource_content_id: resource.id,
            translation: original,
            draft_text:          processed_text,
            current_text:        original.text,
            text_matched:        (original.text == processed_text),
            imported:            false,
            meta_data: {
              "source-data" => {
                "sura"           => surah_id.to_s,
                "aya"            => verse_number.to_s,
                "arabic_text"    => ayah["arabic"].to_s,
                "resource_text"  => ayah["text"].to_s,
                "footnotes"      => fns
              }
            }
          )

          footnotes = original.foot_notes.order('ID ASC')
          need_review ||= footnotes.size != fns.size

          fns.each_with_index do |fn, idx|
            original_footnote = footnotes[idx]
            need_review ||= original_footnote&.text != fn[:text]

            foot = Draft::FootNote.create!(
              draft_translation_id: dt.id,
              resource_content_id:  footnote_resource.id,
              draft_text:           fn[:text],
              current_text:         original_footnote&.text,
              text_matched:         original_footnote&.text == fn[:text],
              foot_note_id:         original_footnote&.id,
            )

            processed_text = processed_text.gsub(fn[:placeholder], foot.id.to_s)
          end

          dt.draft_text = fix_formatting(processed_text)
          dt.footnotes_count = dt.foot_notes.count
          dt.current_footnotes_count = dt.foot_notes.size
          dt.need_review = need_review
          dt.save!
          created_count += 1
        end
      end
    end

    puts "Imported #{created_count} Draft::Translation records."
  end
end
