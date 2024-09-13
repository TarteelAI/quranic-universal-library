class TajweedRules
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
    "18": "#AAAAAA"
  }

  def self.rules
    TAJWEED_RULES
  end

  def self.name(index)
    TAJWEED_RULES.key(index.to_i)
  end

  def self.index(name)
    TAJWEED_RULES[name.to_s]
  end

  def self.names
    TAJWEED_RULES.keys
  end

  def self.color_by_name(rule_name)
    RULES_COLORS[index(rule_name).to_s.to_sym]
  end

  def self.color_by_index(rule_index)
    RULES_COLORS[rule_index.to_s.to_sym]
  end

  def self.documentation
    {
      ham_wasl: {
        name: 'Hamzat Al Wasl',
        description: "Hamzat Al Wasl is represented by small (ص) on top of Alif and it is read when the verse is started by it. However, if it comes in the middle of verse at the start of a word or within a word, then it is silent. Also, if it comes after a Waqf (Pause) sign at the beginning of a word and you stop at that sign, then it is read.",
        font_code: 'B',
        examples: ['1:1:2', '2:3:3'],
        links: [""],
        index: 1
      },
      laam_shamsiyah: {
        name: 'Laam Ash-Shamsiyyah - (اللام الشمسية)',
        description: "Laam Ash-Shamsiyyah - (اللام الشمسية) Silent Laam within a word.",
        font_code: 'C',
        examples: ['1:1:3'],
        links: ["https://mualim-alquran.com/en/laam-shamsiyyah"],
        index: 2
      },
      slnt: {
        name: 'Silent',
        description: "Represents letters that are not pronounced. For instance, the silent “L” in “اَلشَّمْس” (ash-shams) is never pronounced. Similarly, the Noon in “كَأَن لَّمْ” (ka’an lamma) is pronounced like “كَأَلَّمْ” (ka’allam).",
        font_code: 'C',
        examples: ['1:1:3'],
        links: [""],
        index: 7
      },
      alif_al_tafreeq: {
        name: 'Alif Al Tafreeq (Al Jama’a) – (ألف التفريق (الجماعة))',
        description: "The silent Alif, usually at the end of the word or sometimes in the middle.",
        font_code: 'C',
        examples: ['2:6:3'],
        links: [""],
        index: ''
      },
      marsum_khila: {
        name: 'Marsum Khilaf Al Lafz - (المرسوم خلاف اللفظ)',
        description: "Words which are drawn not like how they are pronounced having vowel/diacritic.",
        font_code: 'C',
        examples: ['2:3:5'],
        links: [""],
        index: ''
      },
      madda_normal: {
        name: '',
        description: "",
        font_code: '',
        examples: [''],
        links: [""],
        index: ''
      },

      madda_permissible: {
        name: '',
        description: "",
        font_code: '',
        examples: [''],
        links: [""],
        index: ''
      },

      madda_necessary: {
        name: '',
        description: "",
        font_code: '',
        examples: [''],
        links: [""],
        index: ''
      },

      idgham_wo_ghunnah: {
        name: '',
        description: "",
        font_code: '',
        examples: [''],
        links: [""],
        index: ''
      },

      ghunnah: {
        name: '',
        description: "",
        font_code: '',
        examples: [''],
        links: [""],
        index: ''
      },

      qalaqah: {
        name: '',
        description: "",
        font_code: '',
        examples: [''],
        links: [""],
        index: ''
      },

      ikhafa: {
        name: '',
        description: "",
        font_code: '',
        examples: [''],
        links: [""],
        index: ''
      },

      madda_obligatory_monfasel: {
        name: '',
        description: "",
        font_code: '',
        examples: [''],
        links: [""],
        index: ''
      },

      madda_obligatory_mottasel: {
        name: '',
        description: "",
        font_code: '',
        examples: [''],
        links: [""],
        index: ''
      },

      idgham_ghunnah: {
        name: '',
        description: "",
        font_code: '',
        examples: [''],
        links: [""],
        index: ''
      },

      ikhafa_shafawi: {
        name: '',
        description: "",
        font_code: '',
        examples: [''],
        links: [""],
        index: ''
      },

      idgham_shafawi: {
        name: '',
        description: "",
        font_code: '',
        examples: [''],
        links: [""],
        index: ''
      },

      iqlab: {
        name: '',
        description: "",
        font_code: '',
        examples: [''],
        links: [""],
        index: ''
      },

      idgham_mutajanisayn: {
        name: '',
        description: "",
        font_code: '',
        examples: [''],
        links: [""],
        index: ''
      },

      idgham_mutaqaribayn: {
        name: '',
        description: "",
        font_code: '',
        examples: [''],
        links: [""],
        index: ''
      }
    }
  end

  def self.rule_groups
    {
       heavy_and_light_letters: {
        name: 'Heavy and Light letters(Tarqeeq & Tafkheem)',
        rules: [:tafkheem, :tarqeeq]
      },
      noon_saakin_and_tanween: {
        name: 'Noon Saakin and Tanween',
        rules: [
          :izhar,
          :iqlab,
          :ikhfaa,
          idgham: [:idgham_wo_ghunnah, :idgham_ghunnah],
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
end
