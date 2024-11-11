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
    rules.key(index.to_i) || raise_invalid_rule(index)
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

  def documentation
    {
      ham_wasl: {
        name: 'Hamzat Al Wasl',
        description: "Hamzat Al Wasl is represented by small (ص) on top of Alif and it is read when the verse is started by it. However, if it comes in the middle of verse at the start of a word or within a word, then it is silent. Also, if it comes after a Waqf (Pause) sign at the beginning of a word and you stop at that sign, then it is read.",
        rule_letters: "ٱ",
        examples: ['1:1:2', '2:3:3'],
        links: [
          "https://www.ibnulyemenarabic.com/arabic-language/free-arabic-language-lessons/silent-alif-al-wasl/",
          "https://shaykhi.com/hamzaul-wasl/",
          "https://riwaqalquran.com/blog/hamzatul-wasl/"
        ],
        alias: ['connecting hamza']
      },
      laam_shamsiyah: {
        name: 'Laam Ash-Shamsiyyah - (اللام الشمسية)',
        description: "Laam Ash-Shamsiyyah - (اللام الشمسية) Silent Laam within a word.",
        examples: ['1:1:3'],
        links: ["https://mualim-alquran.com/en/laam-shamsiyyah"]
      },
      slnt: {
        name: 'Silent',
        description: "Represents letters that are not pronounced. Generally any letter without hakrat will be Silent. For instance, the silent <span class='qpc-hafs'>ل</span> in “اَلشَّمْس” (ash-shams) is never pronounced. Similarly, the Noon in “كَأَن لَّمْ” (ka’an lamma) is pronounced like “كَأَلَّمْ” (ka’allam).",
        examples: ['1:1:3'],
        links: ["https://alphabet.quranacademy.org/en/lesson/tajweed/silent-letters"]
      },
      alif_al_tafreeq: {
        name: 'Alif Al Tafreeq (Al Jama’a)',
        description: "The silent Alif, usually at the end of the word or sometimes in the middle.",
        examples: ['2:6:3'],
        links: [""],
        alias: ['(ألف التفريق (الجماعة))']
      },

      marsum_khila: {
        name: 'Marsum Khilaf Al Lafz - (المرسوم خلاف اللفظ)',
        description: "Words which are drawn not like how they are pronounced having vowel/diacritic.",
        examples: ['2:3:5'],
        links: [""]
      },

      madda_normal: {
        name: 'Normal Prolongation: 2 Vowels',
        description: "",
        examples: [''],
        links: [
          "https://alphabet.quranacademy.org/en/lesson/tajweed/small-letters-in-quran",
          "https://alphabet.quranacademy.org/en/lesson/tajweed/madd-rules/madd-rules"
        ]
      },

      madda_permissible: {
        name: 'Permissible Prolongation: 2, 4, 6 Vowels',
        description: "",
        examples: [''],
        links: [""]
      },

      madda_necessary: {
        name: 'Necessary Prolongation: 6 Vowels',
        description: "",
        font_code: '',
        examples: [''],
        links: [""]
      },

      ghunnah: {
        name: 'Ghunnah',
        description: "Ghunnah refers to the nasal sound made when pronouncing certain letters in the Quran. It occurs primarily with the letters ن  and م  when they have a shaddah (ّ) ",
        rule_letters: "مّ OR نّ",
        examples: [''],
        links: [""]
      },

      qalaqah: {
        name: 'Qalaqah',
        description: "Qalqalah literally translates to 'echo' or 'reverberation'. Qalqalah refers to the echoing or shaking sound produced when certain letters are pronounced with Sukoon, which indicates no vowel sound.",
        examples: [''],
        rule_tip: "Qalqalah rule apply when any of these letters <span class='qpc-hafs'>ق ط ب ج د</span> has Sukun <span class=qpc-hafs>ـْ</span>",
        rule_letters: "ْق ْط ْب ْج ْد",
        links: [
          "https://bayanulquran-academy.com/qalqalah-in-tajweed/"
        ]
      },

      madda_obligatory_monfasel: {
        name: 'Madd Al-Munfasil 2, 4, or 5 Vowels',
        description: "Occurs when a Madd letter is at the end of a word, followed by a Hamzah (ء) at the beginning of the next word.",
        examples: [''],
        links: [""]
      },

      madda_obligatory_mottasel: {
        name: 'Madd Al-Muttasil',
        description: "Occurs when a Madd letter is followed directly by a Hamzah (ء) in the same word. The elongation is typically 4–5 counts",
        examples: [''],
        links: [""]
      },

      idgham_ghunnah: {
        name: 'Idgham with Ghunnah',
        description: "Idgham is joining a non-vowel with a vowel so that the two letters become one letter of the second type. Idgham With Ghunna is the first type of Idgham, which is called Idgham with nasalization (Ghunnah). Ghunnah is a sound that comes out of our noses.",
        examples: [''],
        rule_letters: "(ي، ن، م، و) < (نْ or ـًـٍـٌ)",
        links: [
          "https://alphabet.quranacademy.org/en/lesson/tajweed/nun-with-sukun-and-tanween/idgham",
          "https://riwaqalquran.com/blog/what-is-idgham-in-tajweed/",
          "https://nooracademy.com/idghaam"
        ]
      },

      idgham_wo_ghunnah: {
        name: 'Idgham without ghunnah',
        description: "",
        rule_letters: "(ل,ر) < (نْ or ـًـٍـٌ)",
        examples: [''],
        links: [
          "https://alphabet.quranacademy.org/en/lesson/tajweed/nun-with-sukun-and-tanween/idgham",
          "https://riwaqalquran.com/blog/what-is-idgham-in-tajweed/",
          "https://nooracademy.com/idghaam",
          "https://kalimah-center.com/types-of-idgham/"
        ]
      },

      ikhafa_shafawi: {
        name: "Ikhafa' Shafawi - With Meem",
        description: "“Ikhfaa Shafawi” in Tajweed involves concealing the sound of the letter Meem sakinah (م) when followed by the letter (ب), while maintaining the nasal sound (ghunnah) for approximately two seconds.",
        examples: ['105:4:1'],
        links: [
          'https://kalimah-center.com/ikhfaa-shafawi/',
          "https://rtrjax.wixsite.com/easytajweed/copy-of-chapter-17-hurooful-muqatta"
        ]
      },

      idgham_shafawi: {
        name: 'Idgham Shafawi - With Meem',
        description: "If a Meem comes after Meem Sakin, then that Meem Sakin will merge with the following Meem, and you'll do Idghaam",
        examples: [''],
        links: [
          "https://alphabet.quranacademy.org/en/lesson/tajweed/mim-with-sukun",
          "https://rtrjax.wixsite.com/easytajweed/copy-of-chapter-17-hurooful-muqatta"
        ]
      },
      izhar_shafawi: {
        name: 'Izhar Shafawi - With Meem',
        description: "Any letter except Ba or Meem comes after Meem Sakin, Izhar Shafawi will be applied. These letters(26 of them) will be read clearly.",
        examples: [''],
        links: [
          "https://alphabet.quranacademy.org/en/lesson/tajweed/mim-with-sukun",
          "https://rtrjax.wixsite.com/easytajweed/copy-of-chapter-17-hurooful-muqatta"
        ]
      },

      iqlab: {
        name: 'Iqlab',
        description: "Iqlab means to convert something into another. If the letter Baa comes after noon saakin or tanween, “noon sound” will be changed into Meem and recited with ghunnah. Simply, turning noon sound into a meem sound, and still pronouncing the letter “Baa”",
        rule_letters: "(ب) < (نْ or ـًـٍـٌ)",
        examples: [''],
        links: ["https://bayanulquran-academy.com/iqlab-in-tajweed"]
      },

      idgham_mutajanisayn: {
        name: 'Idgham - Mutajanisayn',
        description: "",
        examples: [''],
        links: [""],
      },

      idgham_mutaqaribayn: {
        name: 'Idgham - Mutaqaribayn',
        description: "",
        examples: [''],
        links: [""],
      },

      ikhafa: {
        name: 'Ikhfaa',
        description: "",
        examples: [],
        rule_letters: "(ت,ث,ج,د,ذ,ز,س,ش,ص,ض,ط,ظ,ف,ق,ك) < (نْ or ـًـٍـٌ)",
        links: [
          "https://alphabet.quranacademy.org/en/lesson/tajweed/nun-with-sukun-and-tanween/ikhfa"
        ]
      },

      izhar: {
        name: 'Izhar',
        description: "Izhhaar means ‘to make clear or distinct’. In the context of the recitation of the Qur’an, it means ‘pronouncing a letter without ġunnah, i.e. without a sound from the nasal cavity.",
        rule_tip: "If a Noon Saakin or a Tanween <span class='qpc-hafs fs-auto'>نْ or ـًـٍـٌ</span> is followed by any of throat letters <span class='fs-auto qpc-hafs'>ا,ح,خ,ع,غ,ه </span>, the Noon Saakin or the Tanween is pronounced clearly without ġunnah",
        examples: ['1:7:3'],
        rule_letters: "(ا,ح,خ,ع,غ,ه) < (نْ or ـًـٍـٌ)",
        links: [
          "https://mualim-alquran.com/en/iz%CC%A4haar-(noon-saakin-and-tanween)",
          "https://www.quranmyway.com/al-ith-haaral-haliqe/",
          "https://alphabet.quranacademy.org/en/lesson/tajweed/nun-with-sukun-and-tanween/izhar"
        ]
      },
      tafkheem: {
        name: 'tafkheem',
        description: '',
        examples: [],
        links: [
          'https://alphabet.quranacademy.org/en/lesson/tajweed/khuruful-istila',
          'https://www.abouttajweed.com/tajweed-rules/53-tafkheem-and-tarqeeq/57-tafkheem-and-tarqeeq-part-1'
        ]
      },
      tarqeeq: {
        name: 'Tarqeeq',
        description: '',
        examples: [],
        links: [
          'https://alphabet.quranacademy.org/en/lesson/tajweed/khuruful-istila',
          'https://www.abouttajweed.com/tajweed-rules/53-tafkheem-and-tarqeeq/57-tafkheem-and-tarqeeq-part-1'
        ]
      },
      madd_al_tamkeen: {
        name: "Al-Madd Al-Tamkeen",
        description: "Al-Madd Al-Tamkeen occurs when a yaa mushaddadah <span class='qpc-hafs'>ــيِّــ</span> with a kasr is followed by a yaa saakinah. This occurs only within a word, as words cannot start with a sukoon",
        examples: [],
        links: [
          "https://tajweed.me/2011/07/12/al-madd-al-tamkeen-tajweed-rule/"
        ]
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
