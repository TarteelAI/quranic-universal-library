class SpotTestPairGenerator < OpenaiAgent
  SKIP_VERSE_WORDS_COUNT_THRESHOLD = 20
  WAQF_SIGNS = ['ۖ', 'ۚ', 'ۗ'].freeze
  THREE_DOTS_SIGN = 'ۛ'

  def generate(ayah)
    words = ayah_words(ayah)
    waqfs = detect_waqfs(words)

    result = generate_response(
      system_prompt,
      build_prompt(words, waqfs),
      temperature: 1
    )

    if result
      JSON.parse(result)
    else
      []
    end
  end

  def waqf_positions(ayah)
    words = ayah_words(ayah)
    detect_waqfs(words)
  end

  private

  def ayah_words(ayah)
    ayah.text_qpc_hafs.split(/\s+/)
  end

  def detect_waqfs(words)
    waqfs = []
    three_dots_indexes = []
    words.each_with_index do |word, idx|
      waqfs << idx + 1 if WAQF_SIGNS.any? { |w| word.include?(w) }

      if word.include?(THREE_DOTS_SIGN)
        three_dots_indexes << idx + 1
      end
    end

    if three_dots_indexes.present?
      waqfs << three_dots_indexes.first
    end

    waqfs.uniq
  end

  def build_prompt(words, waqfs)
    words_json = JSON.generate(words)
    waqfs_json = JSON.generate(waqfs)

    <<~PROMPT
      You are given a list of words representing a Qur'anic ayah and a list of word indexes containing permissible waqf signs. Your task is to generate spot-test pairs for memorisation following these rules:

      1. Split the ayah only when a clear topic, ruling, or narrative unit is complete.
      2. Never stop in the middle of a legal ruling, condition, exception, or cause-effect chain.
      3. If a topic ends but only a few words remain, merge them into the same chunk.
      4. Multiple waqf signs may exist inside a single chunk if the topic is continuous.
      5. Prefer medium-length chunks (minimum 10 words and maximum ~30 words), but topic integrity overrides size.
      6. If the ayah has no waqf signs create chunks based on topic integrity. If ayah has more then 30 words, keep the minimum chunk size of ~10 words. For short ayahs only create one chunk.

      Output **valid JSON only** in this format:

      {
        "spot_test_pairs": [
          {
            "start": <start word index>,
            "stop": <end word index>,
            "words": <stop - start + 1>
          }
        ]
      }

      Do NOT modify the waqfs array. Use it only for reference.

      Input:
      {
        "words": #{words_json},
        "waqfs": #{waqfs_json}
      }
    PROMPT
  end

  def system_prompt
    'You are a helpful assistant that outputs JSON for Quran memorisation spot tests.'
  end
end