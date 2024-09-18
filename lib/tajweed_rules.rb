class TajweedRules
  attr_accessor :color_scheme

  def initialize(color_scheme = 'old')
    @color_scheme = color_scheme
  end

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
    "iqlab" => 15,
    "idgham_mutajanisayn" => 16,
    "idgham_mutaqaribayn" => 17,
    "alif_al_tafreeq" => 18,
    "izhar" => 19
  }

  TAJWEED_RULES_NEW = {
    "ham_wasl" => 1,
    "laam_shamsiyah" => 2,
    "slnt" => 7,

    "izhar" => 19,
    "madd_al_tamkeen" => 20
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
    "15": "#26BFFD",
    "16": "#A1A1A1",
    "17": "#A1A1A1",
    "18": "#AAAAAA",
    "19": "#AAAAAA",
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
        links: [""]
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
        links: [""]
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

      idgham_wo_ghunnah: {
        name: 'Idgham without ghunnah',
        description: "",
        examples: [''],
        links: [""]
      },

      ghunnah: {
        name: 'Ghunnah',
        description: "",
        examples: [''],
        links: [""]
      },

      qalaqah: {
        name: 'Qalaqah',
        description: "",
        examples: [''],
        links: [""]
      },

      ikhafa: {
        name: 'Ikhafa',
        description: "",
        examples: [''],
        links: [""]
      },

      madda_obligatory_monfasel: {
        name: 'Madd Al-Munfasil 2, 4, or 5 Vowels',
        description: "",
        examples: [''],
        links: [""]
      },

      madda_obligatory_mottasel: {
        name: 'Madd Al-Muttasil',
        description: "",
        examples: [''],
        links: [""]
      },

      idgham_ghunnah: {
        name: 'Idgham with Ghunnah',
        description: "",
        examples: [''],
        links: [""]
      },

      ikhafa_shafawi: {
        name: "Ikhafa' Shafawi - With Meem",
        description: "",
        examples: [''],
        links: [""]
      },

      idgham_shafawi: {
        name: 'Idgham Shafawi - With Meem',
        description: "",
        examples: [''],
        links: [""]
      },

      iqlab: {
        name: 'Iqlab',
        description: "",
        examples: [''],
        links: [""]
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
      izhar: {
        name: 'Izhar',
        description: "Izhhaar means ‘to make clear or distinct’. In the context of the recitation of the Qur’an, it means ‘pronouncing a letter without ġunnah, i.e. without a sound from the nasal cavity.",
        rule_tip: "If a Noon Saakin or a Tanween is followed by any of these throat letters, the Noon Saakin or the Tanween is pronounced clearly without ġunnah",
        examples: ['1:7:3', ''],
        links: [
          "https://mualim-alquran.com/en/iz%CC%A4haar-(noon-saakin-and-tanween)",
          "https://www.quranmyway.com/al-ith-haaral-haliqe/"
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
        rules: [
          :izhar,
          :iqlab,
          :ikhfaa,
          idgham: [:idgham_wo_ghunnah, :idgham_ghunnah],
        ],
        links: [
          'https://www.quranmyway.com/rules-of-noon-saakin-and-tanween/'
        ]
      },
      meem_kaakin: {
        name: 'Meem Saakin',
        rules: [:idgham_shafawi, :izhar_shafawi, :iqlab_shafawi]
      },
      qalaqah: {
        name: 'Qalaqah'
      },
      idhaar: {
      },
      prolongation: {
      }
    }
  end

  def raise_invalid_rule(name_or_index)
    raise "Invalid rule name or index #{name_or_index}"
  end
end