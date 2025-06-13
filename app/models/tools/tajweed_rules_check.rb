module Tools
  class TajweedRulesCheck < DataIntegrityChecks
    def self.checks
      [
        :rule_qalqalah,
        :rule_madd_al_munfasil,
        :rule_izhar,
        :rule_iqlaab
      ]
    end

    def self.rule_iqlaab
      {
        name: "Tajweed Rule: <strong>Iqlaab</strong>",
        description: "List of words with Tajweed Rule Iqlaab. Iqlaab is the changing of a Noon Saakin or Tanween to a Meem when followed by a Ba. The word Iqlaab means 'to change'.<div class='alert alert-info'>Iqlaab occurs when a Noon Saakin<span class='qpc-hafs'> (نْ)</span> or Tanween <span class='qpc-hafs'>ـً ـٍ ـٌ</span> is followed by a Ba <span class='qpc-hafs'>ب</span> with a Sukoon <span class='qpc-hafs'>ْ</span></div>",
        table_attrs: ['id', 'location', 'tajweed_image', 'following_tajweed_image', 'tajweed_text', 'next_word_text'],
         fields: [],
        links_proc: {
          id: ->(record, _) do
            [record.id, "/cms/words/#{record.id}"]
          end,
          tajweed_image: ->(record, _) do
            "<img src='#{record.qa_tajweed_image_url}' />".html_safe
          end,
          following_tajweed_image: ->(record, _) do
            "<img src='#{record.qa_tajweed_image_url(record.next_word_location)}' />".html_safe
          end,
          tajweed_text: -> (record, _) do
            "<div class='quran-text qpc-hafs' data-controller='tajweed-highlight'>#{record.text_uthmani_tajweed.html_safe}</div>".html_safe
          end,
          next_word_text: -> (record, _) do
            "<div class='quran-text qpc-hafs' data-controller='tajweed-highlight'>#{record.next_word_tajweed.html_safe}</div>".html_safe
          end
        },
        check: ->(params) do
          noon_saakin_tanween_regex = 'نْ|ً|ٍ|ٌ'

          # Define the regex for the letter 'ب'
          ba_regex = '^[بْ]'

          # ActiveRecord query with self-join to check the next word
          iqlaab_words = Word.unscoped.joins("JOIN words w2 ON words.word_index + 1 = w2.word_index")
                             .where("words.text_uthmani ~* ?", noon_saakin_tanween_regex)
                             .where("w2.text_uthmani ~* ?", ba_regex)
                           .select("words.id, words.location, words.text_uthmani_tajweed, words.char_type_name, w2.id as next_word_id, w2.location as next_word_location, w2.text_uthmani_tajweed as next_word_tajweed")


          paginate(iqlaab_words, params)
        end
      }
    end

    def self.rule_qalqalah
      # https://bayanulquran-academy.com/qalqalah-in-tajweed/
      {
        name: "Tajweed Rule: <strong>Qalqalah</strong>",
        description: "List of words with Tajweed Rule Qalqalah. Qalqalah is the vibration of the sound in the throat that occurs when pronouncing certain letters. The word qalqalah means 'vibrating' or 'shaking'.<div class='alert alert-info'>Qalqalah occurs when one of the five Qalqalah letters (<span class='qpc-hafs'>ق, ط, ب, ج, د</span>) appears with a Sukoon <span class='qpc-hafs'>ْ</span></div>",
        table_attrs: ['id', 'location', 'tajweed_image', 'tajweed_text'],
        fields: [],
        links_proc: {
          id: ->(record, _) do
            [record.id, "/cms/words/#{record.id}"]
          end,
          tajweed_image: ->(record, _) do
            "<img src='#{record.qa_tajweed_image_url}' />".html_safe
          end,
          tajweed_text: -> (record, _) do
            "<div class='quran-text qpc-hafs' data-controller='tajweed-highlight'>#{record.text_uthmani_tajweed.html_safe}</div>".html_safe
          end
        },
        check: ->(params) do
          words = Word.where("text_uthmani~ ?", '[قطبجد]ْ')

          paginate(words, params)
        end
      }
    end

    def self.rule_madd_al_munfasil
      {
        name: "Tajweed Rule: <strong>Madd al Munfasil</strong>",
        description: "List of words with Madd al Munfasil rule. Madd Al-Munfasil, or the separate elongation, occurs when an elongation letter (Alif, Waw, or Ya) is at the end of one word, and a hamzah (ء) is at the beginning of the following word. It is termed “Munfasil” (separate) because the elongation and the hamzah are in separate words.>",
        table_attrs: ['id', 'location', 'tajweed_image', 'following_tajweed_image', 'tajweed_text', 'next_word_text'],
        fields: [],
        links_proc: {
          id: ->(record, _) do
            [record.id, "/cms/words/#{record.id}"]
          end,
          tajweed_image: ->(record, _) do
            "<img src='#{record.qa_tajweed_image_url}' />".html_safe
          end,
          following_tajweed_image: ->(record, _) do
            "<img src='#{record.qa_tajweed_image_url(record.next_word_location)}' />".html_safe
          end,
          tajweed_text: -> (record, _) do
            "<div class='quran-text qpc-hafs' data-controller='tajweed-highlight'>#{record.text_uthmani_tajweed.html_safe}</div>".html_safe
          end,
          next_word_text: -> (record, _) do
            "<div class='quran-text qpc-hafs' data-controller='tajweed-highlight'>#{record.next_word_tajweed.html_safe}</div>".html_safe
          end
        },
        check: ->(params) do
          words = Word.unscoped.joins("LEFT JOIN words w2 ON words.word_index = w2.word_index - 1")
                      .where(
                        "(words.text_uthmani ~ '[اويى]$' AND w2.text_uthmani ~ '^ء|^إ|^أ') OR " +
                          "(words.text_uthmani ~ '[اويى] ء|[اويى] إ|[اويى] أ')"
                      )
                      .select("words.id, words.location, words.text_uthmani_tajweed, w2.id as next_word_id, w2.location as next_word_location, w2.text_uthmani_tajweed as next_word_tajweed")
          paginate(words, params)
        end
      }
    end

    def self.rule_izhar
      {
        name: "Tajweed Rule: <strong>Izhar</strong>",
        description: "List of words with Tajweed Rule Izhar. Izhar is the clear pronunciation of a letter. <div class='alert alert-info'>Izhar Rule: The Izhar rule occurs when a Noon Saakin<span class='qpc-hafs'> (نْ)</span> or Tanween <span class='qpc-hafs'>ـً ـٍ ـٌ</span> is followed by one of the throat letters.
The six throat letters in Arabic are: <span class='qpc-hafs'> ء (Hamzah), ه (Haa), ع (Ain), ح (Haa), غ (Ghain), خ (Khaa)</span></div> ",
        table_attrs: ['id', 'location', 'tajweed_image', 'following_tajweed_image', 'tajweed_text', 'next_word_text'],
        fields: [],
        links_proc: {
          id: ->(record, _) do
            [record.id, "/cms/words/#{record.id}"]
          end,
          tajweed_image: ->(record, _) do
            "<img src='#{record.qa_tajweed_image_url}' />".html_safe
          end,
          following_tajweed_image: ->(record, _) do
            "<img src='#{record.qa_tajweed_image_url(record.next_word_location)}' />".html_safe
          end,
          tajweed_text: -> (record, _) do
            "<div class='quran-text qpc-hafs' data-controller='tajweed-highlight'>#{record.text_uthmani_tajweed.html_safe}</div>".html_safe
          end,
          next_word_text: -> (record, _) do
            "<div class='quran-text qpc-hafs' data-controller='tajweed-highlight'>#{record.next_word_tajweed.html_safe}</div>".html_safe
          end
        },
        check: ->(params) do
          noon_saakin_tanween_regex = 'نْ|ً|ٍ|ٌ'
          throat_letters_regex = '^[ءهعحغخ]'
          #          words = Word.where("text_uthmani ~* ?", "(#{noon_saakin_tanween_regex})#{throat_letters_regex}")

          words = Word.unscoped.joins("JOIN words w2 ON words.word_index + 1 = w2.word_index")
                            .where("words.text_uthmani ~* ?", noon_saakin_tanween_regex)
                            .where("w2.text_uthmani ~* ?", throat_letters_regex)
                            .select("words.id, words.location, words.text_uthmani_tajweed, w2.id as next_word_id, w2.location as next_word_location, w2.text_uthmani_tajweed as next_word_tajweed")
          paginate(words, params)
        end
      }
    end
  end
end
