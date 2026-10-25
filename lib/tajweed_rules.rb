class TajweedRules
  attr_accessor :color_scheme

  def initialize(color_scheme = 'old')
    @color_scheme = color_scheme
  end

  # Rules and color based on: https://alquran.cloud/tajweed-guide
  TAJWEED_RULES = {
    "ham_wasl" => 1,
    "laam_shamsiyah" => 2,
    "madda_normal" => 3,
    "madda_permissible" => 4,
    "madda_necessary" => 5,
    "idgham_wo_ghunnah" => 6,
    "slnt" => 7,
    "ghunnah" => 8,
    "qalaqah" => 9,
    "ikhafa" => 10,
    "madda_obligatory_monfasel" => 11,
    "madda_obligatory_mottasel" => 12,
    "idgham_ghunnah" => 13,
    "ikhafa_shafawi" => 14,
    "idgham_shafawi" => 15,
    "idgham_mutajanisayn" => 16,
    "idgham_mutaqaribayn" => 17,
    "iqlab" => 18
  }

  # Rules and color based on: https://easyquran.com/en/tajweed-rules/
  TAJWEED_RULES_NEW = {
    "ham_wasl" => 1,
    "laam_shamsiyah" => 2,

    "madda_normal" => 3,
    "madda_permissible" => 4,
    "madda_necessary" => 5,

    "slnt" => 7,
    "ghunnah" => 8,

    "qalaqah" => 9,

    # Non saakon or tanween rules
    "ikhafa" => 10,
    "madda_obligatory_mottasel" => 12,
    "madda_obligatory_monfasel" => 11,

    "iqlab" => 16,
    "izhar" => 19,
    "idgham_ghunnah" => 13,
    "idgham_wo_ghunnah" => 6,

    # Meem saakin rules
    "ikhafa_shafawi" => 14,
    "idgham_shafawi" => 15,
    "izhar_shafawi" => 21,

    "madd_al_tamkeen" => 20,
    "tafkheem" => 22,
    "tarqeeq" => 23
  }

  RULES_COLORS = {
    "1": "#AAAAAA",
    "2": "#AAAAAA",
    "3": "#537FFF",
    "4": "#4050FF",
    "5": "#000EBC",
    "6": "#169200",
    "7": "#AAAAAA",
    "8": "#FF7E1E",
    "9": "#DD0008",
    "10": "#9400A8",
    "11": "#2144C1",
    "12": "#2144C1",
    "13": "#169200",
    "14": "#D500B7",
    "15": "#58B800",
    "16": "#A1A1A1",
    "17": "#A1A1A1",
    "18": "#26BFFD",
    "19": "#AAAAAA",
    "21": "#f7630c"
  }

  RULES_COLORS_NEW = {
    "1": "#AAAAAA",
    "2": "#AAAAAA",
    "3": "#537FFF",
    "4": "#4050FF",
    "5": "#000EBC",
    "6": "#169200",
    "7": "#AAAAAA",
    "8": "#FF7E1E",
    "9": "#DD0008",
    "10": "#9400A8",
    "11": "#2144C1",
    "12": "#2144C1",
    "13": "#169200",
    "14": "#D500B7",
    "15": "#26BFFD",
    "16": "#A1A1A1",
    "17": "#A1A1A1",
    "18": "#AAAAAA",
    "19": "#AAAAAA",
    "20": "#AAAAAA"
  }

  def rules
    if color_scheme == 'old'
      TAJWEED_RULES
    else
      TAJWEED_RULES_NEW
    end
  end

  def colors
    if color_scheme == 'old'
      RULES_COLORS
    else
      RULES_COLORS_NEW
    end
  end

  def name(index)
    return if index.blank?
    rules.key(index.to_i)
  end

  def color(name)
    return if name.blank?

    color_by_index index(name)
  end

  def color_by_index(index)
    colors[index.to_s.to_sym] || raise_invalid_rule(index)
  end

  def index(name)
    return if name.blank?
    rules[name.to_s] || raise_invalid_rule(name)
  end

  def names
    rules.keys
  end

  def color_by_name(rule_name)
    color_by_index index(rule_name)
  end

  def color_by_index(rule_index)
    rules[rule_index.to_s.to_sym]
  end

  # Explanation of each rule for the rule pages and the palette.
  # when/how are short HTML, rule_letters is shown in the Quran font.
  def documentation
    qa = 'https://alphabet.quranacademy.org/en/lesson/tajweed'
    noon_or_tanween = "a noon sakinah <span class='qpc-hafs'>نۡ</span> or tanween <span class='qpc-hafs'>ـً ـٍ ـٌ</span>"

    {
      ham_wasl: {
        name: 'Hamzat Al Wasl',
        arabic: 'همزة الوصل',
        description: "A connecting hamza, written as an alif with a small <span class='qpc-hafs'>ص</span> on top (<span class='qpc-hafs'>ٱ</span>). It's only heard when you start reading from it, and it's silent when the word is joined to the one before it.",
        when: "At the start of <span class='qpc-hafs'>ٱل</span>, of some nouns (<span class='qpc-hafs'>ٱسۡم</span>, <span class='qpc-hafs'>ٱبۡن</span>) and of some verbs, like the imperative <span class='qpc-hafs'>ٱهۡدِنَا</span>.",
        how: "<ul class='list-disc ps-5'><li>Joined to the word before: silent, skip it.</li><li>Starting from it: read it with a fatha before <span class='qpc-hafs'>ل</span> of <span class='qpc-hafs'>ٱل</span>, with a damma in verbs whose third letter has a damma (<span class='qpc-hafs'>ٱنظُرۡ</span>), otherwise with a kasra.</li></ul>",
        rule_letters: 'ٱ',
        links: ['https://shaykhi.com/hamzaul-wasl/', 'https://riwaqalquran.com/blog/hamzatul-wasl/']
      },
      laam_shamsiyah: {
        name: 'Laam Ash-Shamsiyyah',
        arabic: 'اللام الشمسية',
        description: "The laam of <span class='qpc-hafs'>ٱل</span> is written but not read before one of the 14 sun letters. The letter after it gets a shaddah instead.",
        when: "<span class='qpc-hafs'>ٱل</span> followed by a sun letter: <span class='qpc-hafs'>ٱلشَّمۡس</span>, <span class='qpc-hafs'>ٱلنَّاس</span>, <span class='qpc-hafs'>ٱلرَّحۡمَٰن</span>.",
        how: "Skip the laam and double the next letter: <i>ash-shams</i>, not <i>al-shams</i>. Before the other 14 letters (moon letters) the laam is read clearly: <span class='qpc-hafs'>ٱلۡقَمَر</span>.",
        rule_letters: 'ت ث د ذ ر ز س ش ص ض ط ظ ل ن',
        links: ['https://mualim-alquran.com/en/laam-shamsiyyah']
      },
      slnt: {
        name: 'Silent',
        arabic: 'حرف لا يُنطق',
        description: "A letter that is written but not pronounced.",
        when: "<ul class='list-disc ps-5'><li>An alif with a small round zero on it, like <span class='qpc-hafs'>أَنَا۠</span> and <span class='qpc-hafs'>ٱلظُّنُونَا۠</span>. It's read only when stopping on the word.</li><li>A madd letter dropped before a sukun or shaddah in the next word, like <span class='qpc-hafs'>فِي ٱلۡأَرۡضِ</span>.</li><li>The alif after a waw of a plural verb, like <span class='qpc-hafs'>ءَامَنُوا۟</span>.</li></ul>",
        how: "Don't read the letter. A letter with a sukun is not silent, it's read without a vowel.",
        links: ["#{qa}/silent-letters"]
      },
      madda_normal: {
        name: 'Normal Prolongation: 2 Vowels',
        arabic: 'المد الطبيعي',
        description: "The natural madd: a madd letter stretched for 2 counts (harakat). It's the base length every other madd builds on.",
        when: "<span class='qpc-hafs'>ا</span> after a fatha, <span class='qpc-hafs'>و</span> after a damma or <span class='qpc-hafs'>ي</span> after a kasra, or a small alif, waw or ya, with no hamza or sukun after it: <span class='qpc-hafs'>قَالَ</span>, <span class='qpc-hafs'>يَقُولُ</span>, <span class='qpc-hafs'>قِيلَ</span>.",
        how: "Stretch the vowel for 2 counts, no more.",
        rule_letters: 'ا و ي ـٰ',
        links: ["#{qa}/madd-rules/madd-rules", "#{qa}/small-letters-in-quran"]
      },
      madda_permissible: {
        name: 'Permissible Prolongation: 2, 4, 6 Vowels',
        arabic: 'المد العارض للسكون',
        description: "A madd letter, or a leen letter (<span class='qpc-hafs'>وۡ</span> or <span class='qpc-hafs'>يۡ</span> after a fatha), followed by a letter that only has a sukun because you stop on it.",
        when: "Stopping at the end of an ayah or at a pause: <span class='qpc-hafs'>ٱلرَّحِيمِ</span> read as <i>ar-raheem</i>, <span class='qpc-hafs'>نَسۡتَعِينُ</span>, <span class='qpc-hafs'>خَوۡفٌ</span>.",
        how: "Stretch 2, 4 or 6 counts. Pick one length and keep it the same in similar places. When you don't stop, it's a normal 2 count madd.",
        links: ["#{qa}/madd-rules/madd-rules"]
      },
      madda_necessary: {
        name: 'Necessary Prolongation: 6 Vowels',
        arabic: 'المد اللازم',
        description: "A madd letter followed by a letter with a sukun or shaddah that is always there, not only when stopping.",
        when: "<ul class='list-disc ps-5'><li>In a word, before a shaddah: <span class='qpc-hafs'>ٱلضَّآلِّينَ</span>, <span class='qpc-hafs'>دَآبَّةٍ</span>. Before a sukun only in <span class='qpc-hafs'>ءَآلۡـَٰٔنَ</span> (10:51 and 10:91).</li><li>In the opening letters of surahs that are named with three letters, like <span class='qpc-hafs'>الٓمٓ</span>, <span class='qpc-hafs'>قٓ</span>, <span class='qpc-hafs'>نٓ</span>.</li></ul>",
        how: "Always stretch 6 counts.",
        links: ["#{qa}/madd-rules/madd-rules"]
      },
      madda_obligatory_mottasel: {
        name: 'Madd Al-Muttasil: 4 or 5 Vowels',
        arabic: 'المد المتصل',
        description: "A madd letter followed by a hamza in the same word. It's obligatory to stretch it longer than the natural madd.",
        when: "<span class='qpc-hafs'>جَآءَ</span>, <span class='qpc-hafs'>ٱلسَّمَآءِ</span>, <span class='qpc-hafs'>سُوٓءَ</span>, <span class='qpc-hafs'>سِيٓـَٔتۡ</span>.",
        how: "Stretch 4 or 5 counts, up to 6 when stopping on the hamza.",
        links: ["#{qa}/madd-rules/madd-rules"]
      },
      madda_obligatory_monfasel: {
        name: 'Madd Al-Munfasil: 2, 4 or 5 Vowels',
        arabic: 'المد المنفصل',
        description: "A madd letter at the end of a word followed by a hamza at the start of the next word. Despite the key's name it's permissible (jaa'iz), not obligatory.",
        when: "<span class='qpc-hafs'>بِمَآ أُنزِلَ</span>, <span class='qpc-hafs'>قُوٓاْ أَنفُسَكُمۡ</span>, <span class='qpc-hafs'>فِيٓ أَنفُسِكُمۡ</span>. Also a ha of a pronoun read with a long vowel before a hamza: <span class='qpc-hafs'>بِهِۦٓ أَن</span>.",
        how: "Stretch 4 or 5 counts (2 is also allowed in Hafs). When stopping on the first word, it's a normal 2 count madd.",
        links: ["#{qa}/madd-rules/madd-rules"]
      },
      madd_al_tamkeen: {
        name: 'Al-Madd Al-Tamkeen',
        arabic: 'مد التمكين',
        description: "A ya with shaddah and kasra followed by a ya with sukun, in the same word.",
        when: "<span class='qpc-hafs'>ٱلنَّبِيِّـۧنَ</span>, <span class='qpc-hafs'>ٱلۡأُمِّيِّـۧنَ</span>, <span class='qpc-hafs'>حُيِّيتُم</span>.",
        how: "Read both ya's clearly so they don't merge, with a natural 2 count madd.",
        links: ['https://tajweed.me/2011/07/12/al-madd-al-tamkeen-tajweed-rule/']
      },
      ghunnah: {
        name: 'Ghunnah: 2 Vowels',
        arabic: 'الغنة',
        description: "A nasal sound from the nose, part of the letters noon and meem. It's strongest when they have a shaddah.",
        when: "<span class='qpc-hafs'>نّ</span> or <span class='qpc-hafs'>مّ</span>: <span class='qpc-hafs'>إِنَّ</span>, <span class='qpc-hafs'>ثُمَّ</span>, <span class='qpc-hafs'>ٱلنَّاسِ</span>.",
        how: "Hold the nasal sound for 2 counts. Ikhfa, iqlab and idgham with ghunnah have the same sound.",
        rule_letters: 'نّ مّ'
      },
      qalaqah: {
        name: 'Qalqalah',
        arabic: 'القلقلة',
        description: "An echo or bounce on five letters when they have a sukun, so they don't sound swallowed.",
        when: "<span class='qpc-hafs'>ق ط ب ج د</span> (<i>qutb jad</i>) with a sukun: <span class='qpc-hafs'>يَجۡعَلُونَ</span>, <span class='qpc-hafs'>أَحَدٌ</span> when stopping.",
        how: "Release the letter with a slight bounce. Light in the middle of a word, stronger when stopping on it (<span class='qpc-hafs'>ٱلۡفَلَقِ</span>), strongest when that letter also has a shaddah (<span class='qpc-hafs'>ٱلۡحَقُّ</span>).",
        rule_letters: 'ق ط ب ج د'
      },
      izhar: {
        name: 'Izhar',
        arabic: 'الإظهار الحلقي',
        description: "Saying #{noon_or_tanween} clearly, without ghunnah, because the next letter comes from the throat.",
        when: "#{noon_or_tanween.capitalize} followed by a throat letter: <span class='qpc-hafs'>مَنۡ ءَامَنَ</span>, <span class='qpc-hafs'>أَنۡعَمۡتَ</span>, <span class='qpc-hafs'>عَلِيمٌ حَكِيمٌ</span>.",
        how: "Read the noon fully and move to the next letter, with no nasal hold.",
        rule_letters: 'ء ه ع ح غ خ',
        links: ['https://mualim-alquran.com/en/iz%CC%A4haar-(noon-saakin-and-tanween)', 'https://www.quranmyway.com/al-ith-haaral-haliqe/', "#{qa}/nun-with-sukun-and-tanween/izhar"]
      },
      ikhafa: {
        name: 'Ikhfa',
        arabic: 'الإخفاء الحقيقي',
        description: "Hiding #{noon_or_tanween}: between saying it clearly and merging it, with ghunnah.",
        when: "#{noon_or_tanween.capitalize} followed by one of 15 letters, in one word or across two: <span class='qpc-hafs'>مِن قَبۡلِ</span>, <span class='qpc-hafs'>أَنتُمۡ</span>, <span class='qpc-hafs'>رِيحٗا صَرۡصَرٗا</span>.",
        how: "Don't touch the tongue to the noon position. Move towards the next letter and hold the ghunnah for 2 counts.",
        rule_letters: 'ت ث ج د ذ ز س ش ص ض ط ظ ف ق ك',
        links: ["#{qa}/nun-with-sukun-and-tanween/ikhfa"]
      },
      iqlab: {
        name: 'Iqlab',
        arabic: 'الإقلاب',
        description: "Turning #{noon_or_tanween} into a hidden meem before <span class='qpc-hafs'>ب</span>. The Mushaf marks it with a small meem.",
        when: "#{noon_or_tanween.capitalize} followed by <span class='qpc-hafs'>ب</span>: <span class='qpc-hafs'>مِنۢ بَعۡدِ</span>, <span class='qpc-hafs'>أَنۢبِئۡهُم</span>, <span class='qpc-hafs'>سَمِيعُۢ بَصِيرٌ</span>.",
        how: "Close the lips lightly for a meem sound and hold the ghunnah for 2 counts, then say the ba.",
        rule_letters: 'ب'
      },
      idgham_ghunnah: {
        name: 'Idgham with Ghunnah',
        arabic: 'الإدغام بغنة',
        description: "Merging #{noon_or_tanween} into the next word's first letter, keeping the ghunnah.",
        when: "#{noon_or_tanween.capitalize} at the end of a word, followed by <span class='qpc-hafs'>ي ن م و</span> (<i>yanmu</i>) at the start of the next: <span class='qpc-hafs'>مَن يَقُولُ</span>, <span class='qpc-hafs'>مِن نِّعۡمَةٍ</span>, <span class='qpc-hafs'>قَوۡلٌ مَّعۡرُوفٌ</span>. Not inside one word: <span class='qpc-hafs'>ٱلدُّنۡيَا</span>, <span class='qpc-hafs'>بُنۡيَٰنٌ</span>, <span class='qpc-hafs'>صِنۡوَانٌ</span>, <span class='qpc-hafs'>قِنۡوَانٌ</span> are read with izhar.",
        how: "Skip the noon, read the next letter as if it had a shaddah and hold the ghunnah for 2 counts.",
        rule_letters: 'ي ن م و',
        links: ["#{qa}/nun-with-sukun-and-tanween/idgham", 'https://kalimah-center.com/types-of-idgham/']
      },
      idgham_wo_ghunnah: {
        name: 'Idgham without Ghunnah',
        arabic: 'الإدغام بغير غنة',
        description: "Merging #{noon_or_tanween} completely into a following <span class='qpc-hafs'>ل</span> or <span class='qpc-hafs'>ر</span>, with no ghunnah.",
        when: "<span class='qpc-hafs'>مِن رَّبِّهِمۡ</span>, <span class='qpc-hafs'>هُدٗى لِّلۡمُتَّقِينَ</span>.",
        how: "Drop the noon entirely and read the lam or ra with a shaddah: <i>mir-rabbihim</i>.",
        rule_letters: 'ل ر',
        links: ["#{qa}/nun-with-sukun-and-tanween/idgham", 'https://kalimah-center.com/types-of-idgham/']
      },
      ikhafa_shafawi: {
        name: "Ikhfa Shafawi",
        arabic: 'الإخفاء الشفوي',
        description: "Hiding a meem sakinah before <span class='qpc-hafs'>ب</span>. Shafawi means of the lips, since meem and ba are both made with the lips.",
        when: "A meem sakinah at the end of a word followed by <span class='qpc-hafs'>ب</span>: <span class='qpc-hafs'>تَرۡمِيهِم بِحِجَارَةٍ</span>, <span class='qpc-hafs'>وَهُم بِٱلۡأٓخِرَةِ</span>.",
        how: "Keep the lips lightly together and hold the ghunnah for 2 counts, then say the ba.",
        rule_letters: 'مۡ ب',
        links: ['https://kalimah-center.com/ikhfaa-shafawi/', "#{qa}/mim-with-sukun"]
      },
      idgham_shafawi: {
        name: 'Idgham Shafawi',
        arabic: 'الإدغام الشفوي',
        description: "A meem sakinah merging into a following meem, also called idgham mithlayn saghir.",
        when: "A meem sakinah followed by <span class='qpc-hafs'>م</span>: <span class='qpc-hafs'>لَهُم مَّا</span>, <span class='qpc-hafs'>كُنتُم مُّؤۡمِنِينَ</span>.",
        how: "Read one meem with a shaddah and hold the ghunnah for 2 counts.",
        rule_letters: 'مۡ م',
        links: ["#{qa}/mim-with-sukun", 'https://rtrjax.wixsite.com/easytajweed/copy-of-chapter-17-hurooful-muqatta']
      },
      izhar_shafawi: {
        name: 'Izhar Shafawi',
        arabic: 'الإظهار الشفوي',
        description: "Saying a meem sakinah clearly before any letter except <span class='qpc-hafs'>ب</span> and <span class='qpc-hafs'>م</span>.",
        when: "<span class='qpc-hafs'>ٱلۡحَمۡدُ</span>, <span class='qpc-hafs'>عَلَيۡهِمۡ غَيۡرِ</span>, <span class='qpc-hafs'>لَكُمۡ فِيهَا</span>.",
        how: "Close the lips for the meem without a nasal hold. Take extra care before <span class='qpc-hafs'>ف</span> and <span class='qpc-hafs'>و</span>, they're made close to the meem and it's easy to hide it there.",
        rule_letters: 'مۡ',
        links: ["#{qa}/mim-with-sukun"]
      },
      tafkheem: {
        name: 'Tafkheem (heavy letter)',
        arabic: 'التفخيم',
        description: "Reading a letter heavy, with a full deep sound, the back of the tongue raised.",
        when: "<ul class='list-disc ps-5'><li>Always heavy: <span class='qpc-hafs'>خ ص ض غ ط ق ظ</span> (<i>khussa daghtin qiz</i>).</li><li>Ra with a fatha or damma: <span class='qpc-hafs'>رَبِّ</span>.</li><li>Lam of <span class='qpc-hafs'>ٱللَّه</span> after a fatha or damma: <span class='qpc-hafs'>قَالَ ٱللَّهُ</span>.</li></ul>",
        how: "Fill the mouth with the sound. Heaviest with a fatha, lighter with a kasra.",
        rule_letters: 'خ ص ض غ ط ق ظ',
        links: ["#{qa}/khuruful-istila", 'https://www.abouttajweed.com/tajweed-rules/53-tafkheem-and-tarqeeq/57-tafkheem-and-tarqeeq-part-1']
      },
      tarqeeq: {
        name: 'Tarqeeq (light letter)',
        arabic: 'الترقيق',
        description: "Reading a letter light, with a thin sound. Most letters are always light; ra and the lam of Allah change.",
        when: "<ul class='list-disc ps-5'><li>Ra with a kasra, or a ra sakinah after a kasra: <span class='qpc-hafs'>رِجَالٌ</span>, <span class='qpc-hafs'>فِرۡعَوۡنَ</span>.</li><li>Lam of <span class='qpc-hafs'>ٱللَّه</span> after a kasra: <span class='qpc-hafs'>بِسۡمِ ٱللَّهِ</span>.</li></ul>",
        how: "Keep the tongue low and the sound thin.",
        links: ['https://www.abouttajweed.com/tajweed-rules/53-tafkheem-and-tarqeeq/57-tafkheem-and-tarqeeq-part-1']
      }
    }
  end

  def rule_groups
    {
      heavy_and_light_letters: {
        name: 'Heavy and Light letters(Tarqeeq & Tafkheem)',
        rules: [:tafkheem, :tarqeeq],
        links: [

        ]
      },
      noon_saakin_and_tanween: {
        name: 'Noon Saakin and Tanween',
        description: "If you see Tanween OR Sakin Noon, one of these four must applies. <ul><li>Izhaar: You will pronounce (or show) the noon</li>  <li>ikhfaa: you will hide the noon</li>, <li>idghaam: you will skip the noon and connect letters before and after noon</li><li>Iqlab: and finally you will transform the noon sound into meem sound</li></ul>",
        rules: [
          :izhar,
          :iqlab,
          :ikhafa,
          idgham: [:idgham_wo_ghunnah, :idgham_ghunnah],
        ],
        links: [
          'https://www.quranmyway.com/rules-of-noon-saakin-and-tanween/'
        ]
      },
      meem_kaakin: {
        name: 'Meem Saakin',
        description: "The rules of meem sakinah are called «shafawi» because the letter meem is pronounced by closing the lips. The word الشَّفَوِيُّ means «lips».",
        rules: [:idgham_shafawi, :izhar_shafawi, :ikhafa_shafawi],
        links: ['https://alphabet.quranacademy.org/en/lesson/tajweed/mim-with-sukun']
      },
      prolongation: {
        name: "Madd",
        description: "Madd (مد) in Tajweed refers to the elongation or stretching of a vowel sound when reciting the Quran. There are different types of Madd rules based on how long the vowel sound is stretched and the conditions for elongation.",
        rules: [

        ]
      }
    }
  end

  def raise_invalid_rule(name_or_index)
    raise "Invalid rule name or index #{name_or_index}"
  end
end
