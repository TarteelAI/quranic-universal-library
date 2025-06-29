module Tools
  class DataIntegrityChecks
    def self.checks
      [
        :compare_two_mushaf_words,
        :compare_mushaf_page_last_and_first_word,
        :compare_mushaf_scripts,
        :mushaf_page_with_start_ayah,
        :mushaf_page_with_bismillah,
        :mushaf_page_with_ayah_spanning_into_multiple_pages,
        :words_without_mushaf_words,
        :mushaf_words_without_word,
        :mushaf_words_with_missing_arabic_text,
        :words_with_missing_arabic_text,
        :ayah_with_different_mushaf_page,
        :mushaf_words_with_incorrect_position,
        :words_with_missing_translations,
        :ayah_with_missing_translations,
        :duplicate_mushaf_words,
        :mushaf_words_with_incorrect_char_type,
        :chapter_with_missing_translated_names,
        :ayah_with_missing_tafsirs,
        :words_without_root,
        :words_without_lemma,
        :words_without_stem,
        :compare_translations,
        :ayah_without_matching_ayahs
      ]
    end

    def self.valid_check?(name)
      respond_to? name
    end

    def self.ayah_with_different_mushaf_page
      {
        name: "Ayah on different Mushaf Page",
        description: "Get list of ayahs that are not on same page in two mushafs",
        table_attrs: ['ayah', 'first_mushaf_page', 'second_mushaf_page'],
        fields: [
          {
            type: :select,
            collection: Mushaf.all.map do |a|
              [a.name, a.id.to_s]
            end,
            name: :first_mushaf_id
          },
          {
            type: :select,
            collection: Mushaf.all.map do |a|
              [a.name, a.id.to_s]
            end,
            name: :second_mushaf_id
          }
        ],
        links_proc: {
          ayah: -> (record, _) do
            [record.verse_key, "/cms/verses/#{record.verse_key}"]
          end,
          first_mushaf_page: -> (record, params) do
            [record.first_mushaf_page, "/cms/mushaf_page_preview?page=#{record.first_mushaf_page}&mushaf=#{params[:first_mushaf_id]}&compare=#{params[:second_mushaf_id]}"]
          end,
          second_mushaf_page: -> (record, params) do
            [record.second_mushaf_page, "/cms/mushaf_page_preview?page=#{record.second_mushaf_page}&mushaf=#{params[:second_mushaf_id]}&compare=#{params[:first_mushaf_id]}"]
          end
        },
        check: ->(params) do
          first_mushaf_id = params[:first_mushaf_id]
          second_mushaf_id = params[:second_mushaf_id]

          if first_mushaf_id && second_mushaf_id
            result = Verse
                       .select("verse_key, CAST(mushaf_pages_mapping->>'1' AS INTEGER) AS first_mushaf_page, CAST(mushaf_pages_mapping->>'2' AS INTEGER) AS second_mushaf_page")
                       .where("CAST(mushaf_pages_mapping->>'1' AS INTEGER) <> CAST(mushaf_pages_mapping->>'2' AS INTEGER)")

            pages_with_difference = []
            result.map do |ayah|
              pages_with_difference << ayah.first_mushaf_page
              pages_with_difference << ayah.second_mushaf_page
            end

            pages_with_difference = pages_with_difference.uniq.sort

            {
              collection: paginate(result, params),
              total_pages_with_difference: pages_with_difference.size,
              different_pages: pages_with_difference.map do |p|
                "<a href='/cms/mushaf_page_preview?mushaf=#{first_mushaf_id}&compare=#{second_mushaf_id}&page=#{p}'>#{p}</a>"
              end.join(', ')
            }
          else
            paginate Verse.none, params
          end
        end
      }
    end

    def self.compare_mushaf_page_last_and_first_word
      {
        name: "Compare Mushaf Page Last and First Word",
        description: "Compare last and first word of two mushaf pages",
        table_attrs: ['id', 'first_mushaf_first_word', 'second_mushaf_first_word', 'first_mushaf_last_word', 'second_mushaf_last_word'],
        fields: [
          {
            type: :select,
            collection: Mushaf.all.map do |a|
              [a.name, a.id.to_s]
            end,
            name: :first_mushaf_id
          },
          {
            type: :select,
            collection: Mushaf.all.map do |a|
              [a.name, a.id.to_s]
            end,
            name: :second_mushaf_id
          },
          {
            type: :select,
            collection: [['First word', 'first'], ['Last word', 'last'], ['Both first and last word', 'both']],
            name: :compare_field
          }
        ],
        links_proc: {
          first_mushaf_first_word: -> (record, _) do
            w = Word.find(record.first_mushaf_first_word_id)
            [w.humanize, "/cms/mushaf_page_preview?page=#{record.page_number}&mushaf=#{record.first_mushaf_id}&compare=#{record.second_mushaf_id}&word=#{w.id}"]
          end,
          first_mushaf_last_word: -> (record, _) do
            w = Word.find(record.first_mushaf_last_word_id)
            [w.humanize, "/cms/mushaf_page_preview?page=#{record.page_number}&mushaf=#{record.first_mushaf_id}&compare=#{record.second_mushaf_id}&word=#{w.id}"]
          end,
          second_mushaf_first_word: -> (record, _) do
            w = Word.find(record.second_mushaf_first_word_id)
            [w.humanize, "/cms/mushaf_page_preview?page=#{record.page_number}&mushaf=#{record.second_mushaf_id}&compare=#{record.first_mushaf_id}&word=#{w.id}"]
          end,
          second_mushaf_last_word: -> (record, _) do
            w = Word.find(record.second_mushaf_last_word_id)
            [w.humanize, "/cms/mushaf_page_preview?page=#{record.page_number}&mushaf=#{record.second_mushaf_id}&compare=#{record.first_mushaf_id}&word=#{w.id}"]
          end,
        },
        check: ->(params) do
          first_mushaf_id = params[:first_mushaf_id]
          second_mushaf_id = params[:second_mushaf_id]
          compare_filed = params[:compare_field] || 'both'

          if first_mushaf_id && second_mushaf_id
            conditions = {
              'first' => "mushaf_pages.first_word_id <> mp2.first_word_id",
              'last' => "mushaf_pages.last_word_id <> mp2.last_word_id",
              'both' => "mushaf_pages.first_word_id <> mp2.first_word_id OR mushaf_pages.last_word_id <> mp2.last_word_id"
            }
            condition = conditions[compare_filed] || conditions['both']

            pages = MushafPage
                      .joins("INNER JOIN mushaf_pages AS mp2 ON mushaf_pages.page_number = mp2.page_number AND mushaf_pages.mushaf_id = #{first_mushaf_id} AND mp2.mushaf_id = #{second_mushaf_id}")
                      .where(condition)

            result = pages.select(
              "mushaf_pages.page_number",
              "mushaf_pages.mushaf_id AS first_mushaf_id",
              "mp2.mushaf_id AS second_mushaf_id",

              "mushaf_pages.first_word_id AS first_mushaf_first_word_id",
              "mushaf_pages.last_word_id AS first_mushaf_last_word_id",

              "mp2.first_word_id AS second_mushaf_first_word_id",
              "mp2.last_word_id AS second_mushaf_last_word_id"
            )

            pages_with_difference = result.map(&:page_number).uniq.sort

            {
              collection: paginate(result, params),
              total_pages_with_difference: pages_with_difference.size,
              different_pages: pages_with_difference.map do |p|
                "<a href='/cms/mushaf_page_preview?mushaf=#{first_mushaf_id}&compare=#{second_mushaf_id}&page=#{p}'>#{p}</a>"
              end.join(', ')
            }
          else
            paginate MushafPage.none, params
          end
        end
      }
    end

    def self.words_without_root
      {
        name: "Words without root",
        description: "List of words that don't have root",
        table_attrs: ['id', 'location', 'text_uthmani'],
        fields: [],
        check: ->(params) do
          results = Word.without_root
          paginate(results, params)
        end
      }
    end

    def self.words_without_stem
      {
        name: "Words without stem",
        description: "List of words that don't have stem",
        table_attrs: ['id', 'location', 'text_uthmani'],
        fields: [],
        check: ->(params) do
          results = Word.without_stem
          paginate(results, params)
        end
      }
    end

    def self.ayah_without_matching_ayahs
      {
        name: "Ayahs with no related ayahs",
        description: "List of ayahs that has no matching/related ayahs",
        table_attrs: ['id', 'key', 'text'],
        fields: [],
        links_proc: {
          id: ->(record, _) do
            [record.id, "/cms/verses/#{record.id}"]
          end,
          key: ->(record, _) do
            record.verse_key
          end,
          text: -> (record, _) do
            "<div class='quran-text qpc-hafs'>#{record.text_qpc_hafs}</div>".html_safe
          end
        },
        check: ->(params) do
          # m = Morphology::MatchingVerse
          # results = Verse.joins("left join #{m.table_name} on verses.id = #{m.table_name}.verse_id").where('verses.id is null')
          # related ayah and verses are in two different db, join isn't possible
          results = Verse.where.not(id: Morphology::MatchingVerse.pluck(:verse_id).uniq)

          paginate(results, params)
        end
      }
    end

    def self.mushaf_page_with_ayah_spanning_into_multiple_pages
      {
        name: "Mushaf pages where ayahs doens't end of same page",
        description: "List of mushaf pages where ayah doesn't end on the same page.",
        table_attrs: ['page_number', 'first_word', 'last_word'],
        paginate: false,
        links_proc: {
          page_number: -> (record, _) do
            [record.page_number, "/cms/mushaf_pages/#{record.id}"]
          end,
          first_word: -> (record, _) do
            [record.first_word.location, "/cms/mushaf_pages/#{record.id}?word=#{record.first_word.id}"]
          end,
          last_word: -> (record, _) do
            [record.last_word.location, "/cms/mushaf_pages/#{record.id}?word=#{record.last_word.id}"]
          end
        },
        fields: [
          {
            type: :select,
            collection: Mushaf.all.map do |a|
              [a.name, a.id.to_s]
            end,
            name: :mushaf_id
          }
        ],
        check: ->(params) do
          mushaf_id = params[:mushaf_id]
          result = []

          if mushaf_id.present?
            MushafPage.where(mushaf_id: mushaf_id).includes(:last_word, :first_word).each do |page|
              if page.last_word.word? || page.first_word.position != 1
                result << page
              end
            end
          else
            result = MushafPage.none
          end

          result
        end
      }
    end

    def self.mushaf_page_with_start_ayah
      {
        name: "Mushaf page with starting ayah",
        description: "List of pages that has first ayah of any surah.",
        table_attrs: ['page_number', 'ayah'],
        paginate: false,
        links_proc: {
          page_number: -> (record, _) do
            [record[1].page_number, "/cms/mushaf_pages/#{record[1].id}"]
          end,
          ayah: -> (record, _) do
            [record[0], "/cms/verses/#{record[0]}"]
          end
        },
        fields: [
          {
            type: :select,
            collection: Mushaf.all.map do |a|
              [a.name, a.id.to_s]
            end,
            name: :mushaf_id
          }
        ],
        check: ->(params) do
          mushaf_id = params[:mushaf_id]
          result = []

          if mushaf_id.present?
            MushafPage.where(mushaf_id: mushaf_id).order('page_number ASC').each do |page|
              mapping = page['verse_mapping']

              mapping.each do |surah, range|
                start, last = range.split('-').map(&:to_i)

                if start == 1
                  result << ["#{surah}:#{start}", page]
                end
              end
            end
          else
            result = MushafPage.none
          end

          result
        end
      }
    end

    def self.mushaf_page_with_bismillah
      {
        name: "Mushaf page with Bismillah",
        description: "List of pages that has Bismillah.",
        table_attrs: ['page_number', 'line_number', 'ayah'],
        paginate: false,
        links_proc: {
          page_number: -> (record, _) do
            [record[0].page_number, "/cms/mushaf_pages/#{record[0].id}"]
          end,
          ayah: -> (record, _) do
            [record[2], "/cms/verses/#{record[2]}"]
          end,
          line_number: -> (record, _) do
            record[1]
          end
        },
        fields: [
          {
            type: :select,
            collection: Mushaf.all.map do |a|
              [a.name, a.id.to_s]
            end,
            name: :mushaf_id
          }
        ],
        check: ->(params) do
          mushaf_id = params[:mushaf_id]

          if mushaf_id.present?
            lines_with_bismillah = MushafLineAlignment.where(mushaf_id: mushaf_id).order('page_number ASC').select(&:is_bismillah?)

            lines_with_bismillah.map do |line|
              page = MushafPage.includes(:first_word).where(mushaf_id: mushaf_id, page_number: line.page_number).first
              [page, line.line_number, page.first_word.location]
            end
          else
            MushafPage.none
          end
        end
      }
    end

    def self.compare_translations
      translations = ResourceContent.translations.one_verse.map do |a|
        ["#{a.id} - #{a.name}", a.id.to_s]
      end

      {
        name: "Compare two translation",
        description: "Compare two translations, see text diff etc",
        table_attrs: [:verse_key, :first_translation, :second_translation, :matched, :diff],
        links_proc: {
          verse_key: -> (record, _) do
            [record.verse_key, "/cms/verses/#{record.verse_key}"]
          end,
          first_translation: -> (record, _) do
            "#{record.first_translation.to_s.html_safe} (<a href='/cms/translations/#{record.id}' target=_blank>#{record.id}</a>)".html_safe
          end,
          second_translation: -> (record, _) do
            "#{record.second_translation.to_s.html_safe} (<a href='/cms/translations/#{record.second_translation_id}' target=_blank>#{record.second_translation_id}</a>)".html_safe
          end,
          diff: -> (record, params) do
            exact_compare = params[:exact_compare] == '1'

            if record.first_translation != record.second_translation
              first = record.first_translation.to_s
              second = record.second_translation.to_s

              if !exact_compare
                first = first.downcase
                second = second.downcase
              end

              if (text_diff = Diffy::SplitDiff.new(first, second, format: :html, allow_empty_diff: true) rescue nil)
                "<div>
  #{text_diff.left.html_safe}
              </div><div>
  #{text_diff.right.html_safe}
              </div>".html_safe
              end
            end
          end,
          matched: -> (record, params) do
            exact_compare = params[:exact_compare] == '1'

            if exact_compare
              record.first_translation == record.second_translation
            else
              record.first_translation.downcase == record.second_translation.downcase
            end
          end
        },
        fields: [
          {
            type: :string,
            name: :verse_key
          },
          {
            type: :select,
            name: :matched,
            collection: [['Any', ''], ['Yes', '1'], ['No', '0']],
          },
          {
            type: :select,
            name: :exact_compare,
            collection: [['Yes', '1'], ['No', '0']],
          },
          {
            type: :select,
            collection: translations,
            name: :first_translation
          },
          {
            type: :select,
            collection: translations,
            name: :second_translation
          }
        ],
        check: ->(params) do
          first_translation_id = params[:first_translation]
          second_translation_id = params[:second_translation]
          verse_key = params[:verse_key]
          matched = params[:matched]
          exact_compare = params[:exact_compare] == '1'

          if first_translation_id && second_translation_id
            translations = Translation
                             .joins("INNER JOIN translations AS tr2 ON translations.verse_id = tr2.verse_id AND translations.resource_content_id = #{first_translation_id} AND tr2.resource_content_id = #{second_translation_id}")

            if verse_key.present?
              translations = translations.where("translations.verse_key = ?", verse_key)
            end

            if matched.present?
              if matched == '1'
                if exact_compare
                  translations = translations.where("translations.text = tr2.text", verse_key)
                else
                  translations = translations.where("LOWER(translations.text) = LOWER(tr2.text)", verse_key)
                end
              elsif matched == '0'
                if exact_compare
                  translations = translations.where("translations.text <> tr2.text", verse_key)
                else
                  translations = translations.where("LOWER(translations.text) <> LOWER(tr2.text)", verse_key)
                end
              end
            end

            result = translations.select(
              :id,
              :verse_key,
              "translations.text AS first_translation",
              "tr2.id AS second_translation_id",
              "tr2.text AS second_translation"
            )
          else
            result = Translation.none
          end

          paginate(result, params)
        end
      }
    end

    def self.compare_mushaf_scripts
      {
        name: "Mushaf Script Comparison",
        description: "This tool compares the script differences between two Mushafs. It helps identify variations in mushaf scripts.",
        table_attrs: ['word_id', 'first_mushaf_text', 'second_mushaf_text', 'page_number'],
        links_proc: {
          word_id: -> (record, _) do
            [record.word.location, "/cms/words/#{record.word_id}"]
          end,
          first_mushaf_text: -> (record, params) do
            text = record.first_mushaf_text
            text += " - (#{record.first_mushaf_text.to_s.length})" if params[:compare_type] == 'length'

            [
              text,
              "/cms/mushaf_page_preview?page=#{record.first_mushaf_page}&mushaf=#{record.first_mushaf_id}&word=#{record.word_id}&compare=#{record.second_mushaf_id}",
            ]
          end,
          second_mushaf_text: -> (record, params) do
            text = record.second_mushaf_text
            text += " - (#{record.second_mushaf_text.to_s.length})" if params[:compare_type] == 'length'

            [
              text,
              "/cms/mushaf_page_preview?page=#{record.second_mushaf_page}&mushaf=#{record.second_mushaf_id}&word=#{record.word_id}&compare=#{record.first_mushaf_id}"
            ]
          end,
          page_number: -> (record, _) do
            record.first_mushaf_page
          end
        },
        fields: [
          {
            type: :select,
            collection: Mushaf.all.map do |a|
              [a.name, a.id.to_s]
            end,
            name: :first_mushaf_id
          },
          {
            type: :select,
            collection: Mushaf.all.map do |a|
              [a.name, a.id.to_s]
            end,
            name: :second_mushaf_id
          },
          {
            type: :select,
            collection: [['Compare Text', 'text'], ['Compare text length', 'length']],
            name: :compare_type
          }
        ],
        check: ->(params) do
          first_mushaf_id = params[:first_mushaf_id]
          second_mushaf_id = params[:second_mushaf_id]
          compare_type = params[:compare_type] || 'text'

          if first_mushaf_id && second_mushaf_id
            first_mushaf = Mushaf.find(first_mushaf_id)
            second_mushaf = Mushaf.find(second_mushaf_id)
            condition = compare_type == 'text' ? "mushaf_words.text <> mw2.text" : "LENGTH(mushaf_words.text) <> LENGTH(mw2.text)"

            if first_mushaf.using_glyphs? || second_mushaf.using_glyphs?
              # Comparing v1 and v2 maybe, both mushaf should be using glyphs.
              # If not return empty results with an error
              # For glyphs, we'll compare the length of the text
              if first_mushaf.using_glyphs? && second_mushaf.using_glyphs?
                matching_words = MushafWord
                                   .joins("INNER JOIN mushaf_words AS mw2 ON mushaf_words.word_id = mw2.word_id AND mushaf_words.mushaf_id = #{first_mushaf.id} AND mw2.mushaf_id = #{second_mushaf.id}")
                                   .where(condition)
              else
                return {
                  error: "Both mushafs should be using glyphs for comparison",
                  collection: MushafWord.none.page(0)
                }
              end
            else
              # Compare text
              matching_words = MushafWord
                                 .joins("INNER JOIN mushaf_words AS mw2 ON mushaf_words.word_id = mw2.word_id AND mushaf_words.mushaf_id = #{first_mushaf.id} AND mw2.mushaf_id = #{second_mushaf.id}")
                                 .where(condition)
            end
          else
            matching_words = MushafWord.none
          end

          result = matching_words.select(
            :word_id,
            "mushaf_words.mushaf_id AS first_mushaf_id",
            "mw2.mushaf_id AS second_mushaf_id",

            "mushaf_words.page_number AS first_mushaf_page",

            "mushaf_words.text AS first_mushaf_text",
            "mw2.text AS second_mushaf_text",
            "mw2.page_number AS second_mushaf_page"
          )

          pages_with_difference = result.map(&:first_mushaf_page).uniq.sort

          {
            collection: paginate(result, params),
            total_pages_with_difference: pages_with_difference.size,
            different_pages: pages_with_difference.map do |p|
              "<a href='/cms/mushaf_page_preview?mushaf=#{first_mushaf_id}&compare=#{second_mushaf_id}&page=#{p}'>#{p}</a>"
            end.join(', ')
          }
        end
      }
    end

    def self.compare_two_mushaf_words
      {
        name: "Compare layout difference of two Mushafs",
        description: "Compare two mushaf words and get list of words that are not on same page/or line",
        table_attrs: ['word_id', 'text', 'first_mushaf_page', 'second_mushaf_page', 'first_mushaf_line', 'second_mushaf_line'],
        links_proc: {
          word_id: -> (record, _) do
            [record.word.location, "/cms/words/#{record.word_id}"]
          end,
          first_mushaf_page: -> (record, _) do
            [record.first_mushaf_page, "/cms/mushaf_page_preview?page=#{record.first_mushaf_page}&mushaf=#{record.first_mushaf_id}&word=#{record.word_id}"]
          end,
          second_mushaf_page: -> (record, _) do
            [record.second_mushaf_page, "/cms/mushaf_page_preview?page=#{record.second_mushaf_page}&mushaf=#{record.second_mushaf_id}&word=#{record.word_id}"]
          end
        },
        fields: [
          {
            type: :select,
            collection: [['Line number', 'line_number'], ['Page number', 'page_number']],
            name: :compare_field
          },
          {
            type: :select,
            collection: Mushaf.all.map do |a|
              [a.name, a.id.to_s]
            end,
            name: :first_mushaf_id
          },
          {
            type: :select,
            collection: Mushaf.all.map do |a|
              [a.name, a.id.to_s]
            end,
            name: :second_mushaf_id
          }
        ],
        check: ->(params) do
          first_mushaf_id = params[:first_mushaf_id]
          second_mushaf_id = params[:second_mushaf_id]
          compare_attr = params[:compare_field].presence || 'page_number'

          if first_mushaf_id && second_mushaf_id
            matching_words = MushafWord
                               .joins("INNER JOIN mushaf_words AS mw2 ON mushaf_words.word_id = mw2.word_id AND mushaf_words.mushaf_id = #{first_mushaf_id} AND mw2.mushaf_id = #{second_mushaf_id}")
                               .where("mushaf_words.#{compare_attr} <> mw2.#{compare_attr}")

            result = matching_words.select(
              :word_id,
              :text,
              "mushaf_words.mushaf_id AS first_mushaf_id",
              "mw2.mushaf_id AS second_mushaf_id",

              "mushaf_words.page_number AS first_mushaf_page",
              "mushaf_words.line_number AS first_mushaf_line",

              "mw2.line_number AS second_mushaf_line",
              "mw2.page_number AS second_mushaf_page"
            )
          else
            result = MushafWord.none
          end

          pages_with_difference = []
          result.each do |r|
            pages_with_difference << r.first_mushaf_page
            pages_with_difference << r.second_mushaf_page
          end
          pages_with_difference = pages_with_difference.uniq.sort

          {
            collection: paginate(result, params),
            total_pages_with_difference: pages_with_difference.size,
            different_pages: pages_with_difference.map do |p|
              "<a href='/cms/mushaf_page_preview?mushaf=#{first_mushaf_id}&compare=#{second_mushaf_id}&page=#{p}'>#{p}</a>"
            end.join(', ')
          }
        end
      }
    end

    def self.mushaf_words_with_incorrect_position
      {
        name: "Mushaf Words with incorrect position in ayah",
        description: "List of mushaf words with incorrect position",
        table_attrs: ['id', 'mushaf_id', 'word_id', 'text', 'word_position', 'position_in_verse'],
        fields: [
          {
            type: :select,
            collection: Mushaf.all.map do |a|
              [a.name, a.id.to_s]
            end,
            name: :mushaf_id
          }
        ],
        check: ->(params) do
          query = "char_type_id NOT IN(#{1}, #{3})"
          mushaf_id = params[:mushaf_id]

          if mushaf_id.present?
            query = "mushaf_words.mushaf_id = #{mushaf_id.to_i} AND (#{query})"
          end

          results = MushafWord.where(query)
          paginate(results, params)

          join_query = "join words on words.id = mushaf_words.word_id"
          mushaf_id = params[:mushaf_id]

          if mushaf_id.present?
            join_query += " AND mushaf_words.mushaf_id = #{mushaf_id.to_i}"
          end

          results = MushafWord.joins(join_query).where('mushaf_words.position_in_verse != words.position')
          paginate(results, params)
        end
      }
    end

    def self.mushaf_words_with_incorrect_char_type
      {
        name: "Mushaf Words with incorrect char type",
        description: "List of mushaf words non word char types. ",
        table_attrs: ['id', 'mushaf_id', 'word_id', 'text', 'char_type_name'],
        fields: [
          {
            type: :select,
            collection: Mushaf.all.map do |a|
              [a.name, a.id.to_s]
            end,
            name: :mushaf_id
          }
        ],
        check: ->(params) do
          query = "char_type_id NOT IN(#{1}, #{3})"
          mushaf_id = params[:mushaf_id]

          if mushaf_id.present?
            query = "mushaf_words.mushaf_id = #{mushaf_id.to_i} AND (#{query})"
          end

          results = MushafWord.where(query)
          paginate(results, params)
        end
      }
    end

    def self.duplicate_mushaf_words
      {
        name: "Duplicate Mushaf Word entries",
        description: "List of Mushaf Word with duplicate entries per Mushaf",
        table_attrs: ['mushaf_id', 'word_id', 'count'],
        paginate: false,
        fields: [
          {
            type: :select,
            collection: Mushaf.all.map do |a|
              [a.name, a.id.to_s]
            end,
            name: :mushaf_id
          }
        ],
        check: ->(params) do
          mushaf_id = params[:mushaf_id]
          records = if mushaf_id.present?
                      MushafWord.where(mushaf_id: mushaf_id.to_i)
                    else
                      MushafWord
                    end

          records.select('mushaf_id, word_id, count(*) as count').group(:mushaf_id, :word_id).having('count(*) > 1')
        end
      }
    end

    def self.words_with_missing_arabic_text
      text_attrs = ["text_uthmani",
                    "text_indopak",
                    "text_imlaei_simple",
                    "text_imlaei",
                    "text_uthmani_simple",
                    "text_uthmani_tajweed",
                    "text_qpc_hafs",
                    "text_indopak_nastaleeq",
                    "text_qpc_nastaleeq"]

      {
        name: "Quran Words with missing Arabic",
        description: "Quran Words with missing Arabic",
        table_attrs: ['id', 'chapter_id', 'text_uthmani', 'char_type_name'],
        fields: [
          {
            type: :select,
            collection: text_attrs,
            name: :script_type
          }
        ],
        check: ->(params) do
          script_type = params[:script_type]

          query = if script_type.present?
                    attr = script_type.to_s.strip

                    "#{attr} IS NULL OR #{attr} = ''"
                  else
                    text_attrs.map do |attr|
                      "#{attr} IS NULL OR #{attr} = ''"
                    end.join(' OR ')
                  end

          results = Word.where(query)
          paginate(results, params)
        end
      }
    end

    def self.mushaf_words_with_missing_arabic_text
      {
        name: "Mushaf Words record without text",
        description: "List of Mushaf Words without text",
        table_attrs: ['id', 'mushaf_id', 'word_id', 'text', 'char_type_name'],
        fields: [
          {
            type: :select,
            collection: Mushaf.all.map do |a|
              [a.name, a.id.to_s]
            end,
            name: :mushaf_id
          }
        ],
        check: ->(params) do
          query = "text = '' OR text IS NULL"
          mushaf_id = params[:mushaf_id]

          if mushaf_id.present?
            query = "mushaf_words.mushaf_id = #{mushaf_id.to_i} AND (#{query})"
          end

          results = MushafWord.where(query)
          paginate(results, params)
        end
      }
    end

    def self.words_without_lemma
      {
        name: "Words without lemma",
        description: "List of Words that don't have lemma",
        table_attrs: ['id', 'location', 'text_uthmani'],
        fields: [],
        check: ->(params) do
          sort_by = params[:sort_by].presence || 'id'
          sort_order = params[:sort_order].presence || 'asc'

          results = Word.without_lemma.order("#{sort_by} #{sort_order}")
          paginate(results, params)
        end
      }
    end

    def self.words_without_stem
      {
        name: "Words without stem",
        description: "List of Words that don't have stem",
        table_attrs: ['id', 'location', 'text_uthmani'],
        fields: [],
        check: ->(params) do
          sort_by = params[:sort_by].presence || 'id'
          sort_order = params[:sort_order].presence || 'asc'

          results = Word.without_stem.order("#{sort_by} #{sort_order}")
          paginate(results, params)
        end
      }
    end

    def self.words_without_root
      {
        name: "Words without root word",
        description: "List of Words that don't have root",
        table_attrs: ['id', 'location', 'text_uthmani'],
        fields: [],
        check: ->(params) do
          sort_by = params[:sort_by].presence || 'id'
          sort_order = params[:sort_order].presence || 'asc'

          results = Word.without_root.order("#{sort_by} #{sort_order}")
          paginate(results, params)
        end
      }
    end

    def self.words_without_mushaf_words
      {
        name: "Missing Words in Mushaf Layout",
        description: "This tool identifies words that are missing from a specific Mushaf layout. It helps ensure that the all Mushaf layout accurately reflects the complete Quran text",
        instructions: [
          "dsd",
          "sd"
        ],
        table_attrs: ['id', 'location', 'text_uthmani', 'page'],
        fields: [
          {
            type: :select,
            collection: Mushaf.all.map do |a|
              [a.name, a.id.to_s]
            end,
            name: :mushaf_id
          }
        ],
        links_proc: {
          page: -> (record, params) do
            mushaf_id = params[:mushaf_id]
            page_words = MushafWord.where(mushaf_id: mushaf_id).where('word_id IN (?)', record.verse.words.pluck(:id))
            page = page_words.detect(&:page_number)&.page_number
            [page, "/mushaf_layouts/#{mushaf_id}/edit?page_number=#{page}"]
          end
        },
        check: ->(params) do
          join_query = "left join mushaf_words on words.id = mushaf_words.word_id"
          mushaf_id = params[:mushaf_id]

          if mushaf_id.present?
            join_query += " AND mushaf_words.mushaf_id = #{mushaf_id.to_i}"
          end

          results = Word.joins(join_query).where('mushaf_words.id is null')
          paginate(results, params)
        end
      }
    end

    def self.mushaf_words_without_word
      {
        name: "Orphan Mushaf Words",
        description: "This tool identifies Mushaf words that do not have associated word records in the dataset. It helps to ensure that all words in the Mushaf are properly linked to their corresponding Quran word.",
        table_attrs: ['id', 'word_id', 'text'],
        check: ->(params) do
          results = MushafWord.joins("left join words on words.id = mushaf_words.word_id").where('words.id is null')
          paginate(results, params)
        end
      }
    end

    def self.chapter_with_missing_translated_names
      {
        name: "Surah with missing translated names",
        description: "List of surahs with missing translated names for specific language",
        table_attrs: ['id', 'name_simple'],
        fields: [
          {
            type: :select,
            collection: TranslatedName.where(resource_type: 'Chapter').select("DISTINCT language_id, language_name").map do |tr|
              [tr.language_name, tr.language_id]
            end,
            name: :language_id
          }
        ],
        check: ->(params) do
          join_query = "left join translated_names on chapters.id = translated_names.resource_id AND translated_names.resource_type = 'Chapter'"
          language_id = params[:language_id]

          if language_id.present?
            join_query += " AND translated_names.language_id = #{language_id.to_i}"
          end

          results = Chapter.joins(join_query).where('chapters.id is null')
          paginate(results, params)
        end
      }
    end

    def self.words_with_missing_translations
      {
        name: "Words with missing translation",
        description: "List of words with missing translation for specific language",
        table_attrs: ['id', 'location', 'text_uthmani'],
        fields: [
          {
            type: :select,
            collection: WordTranslation.select("DISTINCT language_id, language_name").map do |tr|
              [tr.language_name, tr.language_id]
            end,
            name: :language_id
          }
        ],
        check: ->(params) do
          join_query = "left join word_translations on words.id = word_translations.word_id"
          language_id = params[:language_id]

          if language_id.present?
            join_query += " AND word_translations.language_id = #{language_id.to_i}"
          end

          results = Word.joins(join_query).where("words.id is null OR word_translations.text = '' OR  word_translations.text IS NULL")
          paginate(results, params)
        end
      }
    end

    def self.ayah_with_missing_translations
      {
        name: "Ayah with missing translation",
        description: "List of ayahs with missing translation",
        table_attrs: ['id', 'verse_key'],
        fields: [
          {
            type: :select,
            collection: ResourceContent.translations.one_verse.pluck(:name, :id),
            name: :resource_content_id
          }
        ],
        check: ->(params) do
          join_query = "left join translations on verses.id = translations.verse_id"
          resource_content_id = params[:resource_content_id]

          if resource_content_id.present?
            join_query += " AND translations.resource_content_id = #{resource_content_id.to_i}"
          end

          results = Verse.joins(join_query).where("verses.id is null OR translations.text = '' OR  translations.text IS NULL")
          paginate(results, params)
        end
      }
    end

    def self.ayah_with_missing_tafsirs
      {
        name: "Ayah with missing tafsirs",
        description: "List of ayahs with missing tafsirs",
        table_attrs: ['id', 'verse_key'],
        fields: [
          {
            type: :select,
            collection: ResourceContent.tafsirs.one_verse.pluck(:name, :id),
            name: :tafsir_id
          }
        ],
        check: ->(params) do
          join_query = "left join tafsirs on verses.id = tafsirs.verse_id"
          resource_content_id = params[:tafsir_id]

          if resource_content_id.present?
            join_query += " AND tafsirs.resource_content_id = #{resource_content_id.to_i}"
          end

          results = Verse.joins(join_query).where("verses.id is null OR ( group_tafsir_id is NULL AND (tafsirs.text = '' OR  tafsirs.text IS NULL))")
          paginate(results, params)
        end
      }
    end

    protected

    def self.paginate(results, params)
      page = (params[:page] || 0).to_i
      per_page = (params[:per_page] || 20).to_i

      results.page(page).per(per_page)
    end
  end
end
