namespace :grammar do
  task generate_mushaf: :environment do
    mushaf = Mushaf.where(name: 'Grammar colored').first_or_initialize
    mushaf.lines_per_page = 15
    mushaf.pages_count = 604
    mushaf.default_font_name = 'qpc-hafs'
    mushaf.qirat_type_id = 1
    mushaf.save

    qpc_hafs = Mushaf.find(5)

    JOINING_LETTERS = %w[ب ت ث ج ح خ س ش ص ض ط ظ ع غ ف ق ك ل م ن هـ ي]
    TASHKEEL_REGEX = /[\u0610-\u061A\u064B-\u065F\u0670]/

    def uthmani_to_qpc_hafs(uthmani)
      uthmani.gsub("ْ", "ۡ").gsub("۟", "ْ")
    end

    def get_last_letter(text)
      letters_only = text.gsub(TASHKEEL_REGEX, '')
      letters_only[-1]
    end

    def add_zero_width_joiner(text)
      last_letter = get_last_letter(text)
      if JOINING_LETTERS.include?(last_letter)
        "#{text}&zwj;"
      else
        text
      end
    end

    def build_word_text(mushaf_word)
      puts mushaf_word.word_id
      segments = Morphology::WordSegment.where(word_id: mushaf_word.word_id).order('position ASC')
      segment_size = segments.size
      current_segment = 0

      texts = segments.map do |segment|
        next if segment.text_uthmani.blank?
        text = uthmani_to_qpc_hafs(segment.text_uthmani)
        current_segment += 1

        if segment.part_of_speech_key.present?
          if current_segment < segment_size
            text = add_zero_width_joiner(text)
          end
          "<span class='#{segment.part_of_speech_key.downcase} #{segment.get_segment_color}'>#{text}</span>"
        else
          text
        end
      end

      texts.compact_blank.join
    end

    MushafLineAlignment.where(mushaf_id: qpc_hafs.id).find_each do |line|
      l = MushafLineAlignment.where(
        mushaf_id: mushaf.id,
        page_number: line.page_number,
        line_number: line.line_number
      ).first_or_initialize

      l.attributes = line.attributes.except('id', 'mushaf_id', 'created_at', 'updated_at')
      l.save(validate: false)
    end

    MushafPage.where(mushaf_id: qpc_hafs.id).find_each do |page|
      p = MushafPage.where(
        mushaf_id: mushaf.id,
        page_number: page.page_number
      ).first_or_initialize

      p.attributes = page.attributes.except('id', 'mushaf_id', 'created_at', 'updated_at')
      p.save(validate: false)
    end

    MushafWord.order('verse_id asc').where(mushaf_id: qpc_hafs.id).find_each do |word|
      w = MushafWord.where(
        mushaf_id: mushaf.id,
        word_id: word.word_id
      ).first_or_initialize

      w.attributes = word.attributes.except('id', 'mushaf_id', 'created_at', 'updated_at')
      w.text = build_word_text(word) if word.word?
      w.save(validate: false)
    end
  end
end