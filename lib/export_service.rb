class ExportService
  attr_reader :resource

  def initialize(resource)
    @resource = resource
  end

  def get_export_file_name
    name = TRANSLATION_NAME_MAPPING[resource.id] || resource.sqlite_file_name

    name.gsub(/\s+/, '-').chomp('.json').strip
  end

  def export_translation_versions
    mapping = {}

    TRANSLATION_NAME_MAPPING.each do |id, name|
      mapping[name] = {
        updatedAt: ResourceContent.where(id: id).first&.updated_at.to_i
      }
    end

    File.open("translation_versions.json", "wb") do |f|
      f.puts mapping.to_json.gsub('"', "'").gsub("\'updatedAt\'", "updatedAt")
    end
  end

  #TODO: save this to resource content
  TRANSLATION_NAME_MAPPING = {
    920 => 'en-daryabadi',
    131 => 'en-khattab',
    95 => 'en-maududi',
    921 => 'en-qaribullah',
    206 => 'en-ruwwad',
    20 => 'en-sahih',
    922 => 'en-sarwar',
    21 => 'en-shakir',
    84 => 'en-taqi',
    823 => 'en-wahiduddin',
    22 => 'en-yusufali',
    167 => 'en-maarif-ul-quran',
    918 => 'en-arberry',
    919 => 'en-asad',
    149 => 'en-bridges',
    17 => 'en-ghali',
    85 => 'en-haleem',
    203 => 'en-hilali',
    207 => 'en-irving',
    19 => 'en-pickthall',
    777 => 'en-waleed',

    158 => 'ur-bayan-ul-quran',
    156 => 'ur-fe-zilal-ul-quran',
    234 => 'ur-jalandhari',
    54 => 'ur-junagarhi',
    151 => 'ur-mahmud-al-hasan',
    831 => 'ur-maududi-roman',
    97 => 'ur-tafheem',
    819 => 'ur-wahiduddin',

    79 => 'ru-abu-adel',
    45 => 'ru-elmir',
    923 => 'ru-gordy',
    78 => 'ru-ministry-of-awqaf',
    924 => 'ru-nuri',

    28 => 'es-cortes',
    83 => 'es-garcia',
    140 => 'es-montada-eu',
    199 => 'es-montada-la',

    31 => 'fr-hameedullah',
    136 => 'fr-montada',
    779 => 'fr-rashid',

    27 => 'de-bubenheim',
    208 => 'de-reda',
    840 => 'dv-abu-bakr',
    86 => 'dv-office-pm',

    77 => 'tr-diyanet',
    52 => 'tr-elmalili',
    210 => 'tr-rwwad',
    112 => 'tr-shaban',
    124 => 'tr-shahin',

    135 => 'fa-ih',
    29 => 'fa-tagi',

    800 => 'ff-rowad',
    30 => 'fi-finnish',

    225 => 'gu-rabila',
    #32 => 'ha-gumi', duplicate of 115
    115 => 'ha-gummi',
    233 => 'he-dar-al-salam',
    122 => 'hi-omari',
    33 => 'id-affairs',
    134 => 'id-complex',
    141 => 'id-sabiq',

    209 => 'it-othman',
    153 => 'it-roberto',

    35 => 'ja-ryoichi',
    218 => 'ja-saeed',

    222 => 'kk-altai',
    128 => 'km-cambodian',
    771 => 'kn-kannada',
    36 => 'ko-korean',
    219 => 'ko-hamed',
    81 => 'ku-burhan',
    143 => 'ku-saleh',
    232 => 'lg-african-development',
    855 => 'ln-zakariya',
    904 => 'lt-lithuanian',
    788 => 'mk-macedonian',
    224 => 'ml-kunhi',
    80 => 'ml-karakunnu',
    #37 => 'ml-kunhi', duplicate of 224
    226 => 'mr-shafi-ansari',
    38 => 'mn-maranao',
    784 => 'ms-basmeih',
    # 39 => 'ms-basmeih', duplicate of 784
    108 => 'ne-ahl-hadith-central',
    235 => 'nl-faris',
    144 => 'nl-sofian',
    41 => 'no-norwegian',
    797 => 'ny-ibrahim',
    111 => 'om-ghali',
    857 => 'pa-arif',
    42 => 'pl-jozef',
    785 => 'prs-mawlawi',
    118 => 'ps-zakaria',
    103 => 'pt-helmi',
    43 => 'pt-samir',
    44 => 'ro-grigore',
    782 => 'ro-islamic',

    774 => 'rw-rwanda',
    238 => 'sd-mehmood-amroti',
    228 => 'si-ruwwad',
    46 => 'so-abduh',
    786 => 'so-hassan',
    88 => 'sq-hasan',
    89 => 'sq-sherif',
    48 => 'sv-knut',
    231 => 'sw-abdullah-nasir',
    #793 => 'sw-muhsen', duplicate of 49
    49 => 'sw-muhsin',
    133 => 'ta-hameed',
    50 => 'ta-jan-trust',
    229 => 'ta-sheikh-omar',
    227 => 'te-abder',
    139 => 'tg-mirof-mir',
    223 => 'tg-pioneers',
    74 => 'tg-tajik',
    51 => 'th-qpc',
    230 => 'th-society',
    211 => 'tl-dar-al-salam',

    53 => 'tt-tatar',
    801 => 'tw-haroun',
    76 => 'ug-saleh',
    217 => 'uk-mikhailo',

    101 => 'uz-alauddin',
    868 => 'uz-rowwad',
    127 => 'uz-sodiq-yusuf',
    55 => 'uz-sodiq-yusuf-la',
    221 => 'vi-hasan',
    220 => 'vi-ruwwad',
    125 => 'yo-abu-rahimah',
    798 => 'yuw-hamid',
    236 => 'zg-ramdane',
    56 => 'zh-ma-jain',
    109 => 'zh-makin',
    854 => 'aa-abdulkader',
    853 => 'zh-suliman',
    87 => 'am-sadiq',
    120 => 'as-rafeequl-islam',
    75 => 'az-alikhan',
    23 => 'az-azerbaijani',
    781 => 'bg-bulgarian',
    237 => 'bg-tzvetan',
    796 => 'bm-mamady',
    795 => 'bm-suliman',
    380 => 'bn-fathul-majid',
    163 => 'bn-mujibur-rehman',
    162 => 'bn-rawai-al-bayan',
    161 => 'bn-taisirul-quran',
    213 => 'bn-zakaria',
    126 => 'bs-besim',
    214 => 'bs-dar-salam-enter',
    25 => 'bs-mehanovic',
    106 => 'ce-magomed',
    26 => 'cs-czech',
    926 => 'ks-koshur',
    1270 => 'da-baba-gutubu'
  }
end