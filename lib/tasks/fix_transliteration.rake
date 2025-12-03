namespace :fix_transliteration do
  task import_html: :environment do
    # ["18:3", "18:4", "47:5", "85:22"]
    # 85:18 was repeated twice, key for 85:22 were wrong

    PaperTrail.enabled = false
    FileUtils.mkdir_p("tmp/transliterations")
    Utils::Downloader.download("CDN/transliterations/docx-updated.html", "tmp/transliterations/docx-updated.html")

    IMPORTED = {}
    require 'nokogiri'
    resource = ResourceContent.where(id: 1565).first_or_create

    def replace_zah_with_italic(html, verse)
      text = verse.text_qpc_hafs
      doc = Nokogiri::HTML::fragment(html)

      dhal_indexes = text.enum_for(:scan, /ذ/).map { Regexp.last_match.begin(0) }
      za_indexes   = text.enum_for(:scan, /ظ/).map { Regexp.last_match.begin(0) }

      sequence = (dhal_indexes.map { |i| [i, 'ذ'] } + za_indexes.map { |i| [i, 'ظ'] }).sort_by(&:first)

      th_nodes = []
      doc.traverse do |node|
        if node.name == "u" && node.text.strip == "th"
          th_nodes << node
        end
      end

      sequence.each_with_index do |(_, letter), i|
        node = th_nodes[i]
        next unless node

        if letter == 'ظ'
          i_tag = Nokogiri::XML::Node.new('i', doc)
          i_tag.content = "th"
          node.children = i_tag
        end
      end

      doc.to_html
    end

    def fix_zah_text(text, verse)
      th_regex = /<u>th<\/u>/

      dhal_indexes = verse.text_qpc_hafs.enum_for(:scan, /ذ/).map { Regexp.last_match.begin(0) }
      za_indexes = verse.text_qpc_hafs.enum_for(:scan, /ظ/).map { Regexp.last_match.begin(0) }
      letter_sequence = (dhal_indexes.map { |i| [i, 'ذ'] } + za_indexes.map { |i| [i, 'ظ'] }).sort_by(&:first)

      matches = text.enum_for(:scan, th_regex).map { Regexp.last_match.begin(0) }

      letter_sequence.each_with_index do |(_, letter), i|
        match_index = matches[i]
        next unless match_index

        if letter == 'ظ'
          text[match_index, "<u>th</u>".length] = "<u><i>th</i></u>"
        end
      end

      text
    end

    def fix_underline_text(html)
      doc = Nokogiri::HTML::fragment(html)

      doc.css('u').each do |u_tag|
        text = u_tag.text
        if text.include?(' ')
          parts = text.split(' ')
          replacement = parts.map { |word| "<u>#{word}</u>" }.join(' ')
          u_tag.replace(Nokogiri::HTML::fragment(replacement))
        end
      end

      doc.to_html
    end

    def create_transliteration(surah_num, ayah_num, text, resource)
      verse = Verse.where(verse_key: "#{surah_num}:#{ayah_num}").first

      tr = Draft::Translation.where(
        verse_id: verse.id,
        resource_content_id: resource.id
      ).first_or_initialize


      text = fix_underline_text(text).strip
      text2 = replace_zah_with_italic(text.dup, verse)

      tr.draft_text = text2
      tr.save

      IMPORTED[verse.verse_key] = true
      puts "Importing #{verse.verse_key} #{tr.id}"
    end

    html = File.read('tmp/transliterations/docx-updated.html')
    doc = Nokogiri::HTML(html)
    doc.css("a").remove
    doc.css("img").remove

    def extract_bold_classes(css_content)
      bold_classes = []

      css_content.scan(/\.([a-zA-Z0-9_-]+)\s*\{[^}]*font-weight\s*:\s*700[^}]*\}/i) do |match|
        bold_classes << match[0]
      end

      bold_classes
    end

    def extract_underline_classes(css_content)
      underline_classes = []

      css_content.scan(/\.([a-zA-Z0-9_-]+)\s*\{[^}]*text-decoration\s*:\s*underline[^}]*\}/i) do |match|
        underline_classes << match[0]
      end

      underline_classes
    end

    bold_class = extract_bold_classes(doc.css('style').to_s)
    underline_class = extract_underline_classes(doc.css('style').to_s)

    def parse_and_clean_spans(node, bold_class, underline_class)
      node.children.map do |span|
        if span.text?
          span.text
        else
          classes = span['class'].to_s.split
          text = span.text.gsub("\u00A0", ' ') # replace &nbsp;

          if (classes & bold_class).any?
            "<b>#{text}</b>"
          elsif (classes & underline_class).any?
            "<u>#{text}</u>"
          else
            text
          end
        end
      end.compact.join
    end

    current_surah = nil
    current_ayah = nil
    ayah_text_buffer = ""
    doc.css('p').each do |p|
      text = p.text.strip.gsub("\u00A0", ' ')
      next if text.empty?

      if text =~ /\((\d+)\)/
        if current_surah && current_ayah && !ayah_text_buffer.empty?
          create_transliteration(current_surah, current_ayah, ayah_text_buffer.strip, resource)
        end

        current_surah = $1.to_i
        current_ayah = nil
        ayah_text_buffer = ""
        next
      end

      if current_surah.to_i > 1 && text.start_with?('Bismi All')
        next
      end

      if text =~ /^(\d+)\.(.+)/
        if current_surah && current_ayah && !ayah_text_buffer.empty?
          create_transliteration(current_surah, current_ayah, ayah_text_buffer.strip, resource)
        end

        current_ayah = $1.to_i
        ayah_text_buffer = parse_and_clean_spans(p, bold_class, underline_class).sub(/^(\d+)(\s*)\./, '').strip
      elsif current_ayah
        ayah_text_buffer += " " + parse_and_clean_spans(p, bold_class, underline_class).strip
      end
    end

    if current_surah && current_ayah && !ayah_text_buffer.empty?
      create_transliteration(current_surah, current_ayah, ayah_text_buffer.strip, resource)
    end

    Verse.pluck(:verse_key) - IMPORTED.keys
  end
end

