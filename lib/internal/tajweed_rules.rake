namesapce :taweed_rules do
  task update_rules: :environment do
    rules = {
      ham_wasl: 1,
      laam_shamsiyah: 2,
      slnt: 3,
      idgham_ghunnah: 4,
      idgham_wo_ghunnah: 5,
      ikhafa: 6,
      iqlab: 7,
      qalaqah: 8,
      ghunnah: 9,
      idgham_mutajanisayn: 10,
      idgham_mutaqaribayn: 11,
      idgham_shafawi: 12,
      ikhafa_shafawi: 13,
      madda_normal: 14,
      madda_permissible: 15,
      madda_obligatory: 16,
      madda_necessary: 17,

      rule_hamzat_wasl: 1,
      rule_hamzat_wasl: 2,

      rule_madd_permissible_2_4_6: 15,
   
    }
  end

  task parse: :environment do
    rules = {
      1 => 'Hamzat Wasl',
      2 => 'Lam Shamsiyyah',
      3 => 'Silent',
      4 => 'Idgham - With Ghunnah',
      5 => 'Idgham - Without Ghunnah',
      6 => 'Ikhfa',
      7 => 'Iqlab',
      8 => 'Qalqalah',
      9 => 'Ghunnah - 2 Vowels',
      10 => 'Idgham - Mutajanisayn',
      11 => 'Idgham - Mutaqaribayn',
      12 => 'Idgham Shafawi - With Meem',
      13 => "Ikhfa' Shafawi - With Meem",
      14 => 'Madd Normal - 2 Vowel',
      15 => 'Madd Permissible - 2, 4, 6 Vowels',
      16 => 'Madd Obligatory - 4, 5 Vowels',
      17 => 'Madd Necessary - 6 Vowels'
    }

    data = JSON.parse File.read("data/words-data/corpus-data/recite-quran-positions.json")

=begin
    margin-left: 24.8594px;
    margin-top: 19px;
    width: 23px;
    height: 49px;
    opacity: 0.2;
=end

    def calculate(mL, mT, partWidth, partHelight, imgHeight)
      oldH = 100.to_f

      mt = (mT.to_f * imgHeight / oldH).round(2)
      height = (imgHeight.to_f * partHelight / oldH).round(2)

      ml = (mL * imgHeight / oldH).round(2)
      width = (imgHeight * partWidth / oldH).round(2)

      puts "w #{width}  h #{height} ML #{ml} MT #{mt}"
    end

=begin
    1:1:4
    {:g=>"5", :r=>"1", :w=>10, :h=>38, :ml=>100, :mt=>34, :f=>"00004.mp3"},
     {:g=>"5", :r=>"1", :w=>13, :h=>9, :ml=>99, :mt=>24, :f=>"00004.mp3"},

      margin-left: 88.0522px;
    margin-top: 22px;
    width: 9.69565px;
    height: 41.0435px;

    w 13.0  h 9.0 ML 99.0 MT 24.0

     {:g=>"6", :r=>"2", :w=>10, :h=>39, :ml=>89, :mt=>32},

     {:g=>"7", :r=>"15", :w=>25, :h=>10, :ml=>26, :mt=>65},
     {:g=>"7", :r=>"15", :w=>13, :h=>7, :ml=>39, :mt=>77}]

    margin-left: 17.5469px;
    margin-top: 52px;
    width: 33.7031px;
    height: 26px;

    style="margin-left: 86.1409px; margin-top: 21px; width: 11.3043px; height: 7.82609px; border-color: rgb(170, 170, 170);"

      bT
    iH = //
    oldH = 100 // height of global img
      Math.round(bT * iH / oldH)
=end
  end

  task prepare_svg: :environment do
    Dir["data/words-data/quran-w-b-w/*/*.svg"].each do |source|
      path = source.split('/').last.split('.').first
      surah, ayah, word = path.scan(/.{3}/)
      FileUtils.mkdir_p("data/words-data/corpus-data/images/w/svg-color/#{surah.to_i}/#{ayah.to_i}")
      FileUtils.cp(source, "data/words-data/corpus-data/images/w/svg-color/#{surah.to_i}/#{ayah.to_i}/#{word.to_i}.svg")
    end
  end

  task export_ayah_rules: :environment do
    reg = /<tajweed\s+class=(?<rule>[\w]+)>/
    File.open("tajweed_rules.json", "wb") do |file|
      ayah_rules = {}
    Verse.find_each do |verse|
      rules = verse.text_uthmani_tajweed.scan(reg)
      ayah_rules[verse.verse_key] = rules.flatten
    end
      file.puts ayah_rules.to_json
    end
  end
end