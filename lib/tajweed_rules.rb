class TajweedRules
  TAJWEED_RULES = {
    "ham_wasl" => 1,
    "laam_shamsiyah" => 2,
    "madda_normal" => 3,
    "madda_permissible" => 4,
    "madda_necessary" => 5,
    "idgham_wo_ghunnah" => 6 ,
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
    "idgham_mutaqaribayn" => 17
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
    "17": "#A1A1A1"
  }

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
end