class SvgOptimizer
=begin
require 'fileutils'

pre_colour_map = {
  black_text: "353535",
  hamzat_wasl: "aaa",
  lam_shamsiyyah: "aaa",
  silent: "aaa",
  idgham_with_ghunnah: "00a650",
  idgham_without_ghunnah: "00a650",
  ikhfa: "9d48a1",
  iqlab: "f5c000",
  qalqalah: "ff0000",
  ghunnah_2_wowbvbels: "ff8c00",
  idgham_Mutajanisayn: "aaa",
  idgham_Mutaqaribayn: "aaa",
  idgham_shafawi_with_meem: "80c865",
  ikhfa_shafawi_with_meem: "c360ae",
  madd_normal_2_vowels: "4ebbff",
  madd_permissible_2_4_6: "2c96ff",
  madd_obligatory_4_5_vowels: "3564ff",
  madd_necessary_6_vowels: "0052c4"
}

@colour_map = {
  "353535" => pre_colour_map[:black_text],
  "AAA"    => pre_colour_map[:hamzat_wasl],
  "4FBBFE" => pre_colour_map[:madd_normal_2_vowels],
  "2C94FE" => pre_colour_map[:madd_permissible_2_4_6],
  "2D94FE" => pre_colour_map[:madd_permissible_2_4_6],
  "50BBFE" => pre_colour_map[:madd_normal_2_vowels],
  "333"    => pre_colour_map[:black_text],
  "0253C4" => pre_colour_map[:madd_necessary_6_vowels],
  "0153C4" => pre_colour_map[:madd_necessary_6_vowels],
  "EEEFF0" => pre_colour_map[:remove],
  "02A652" => pre_colour_map[:idgham_with_ghunnah],
  "01A652" => pre_colour_map[:idgham_with_ghunnah],
  "FE8E01" => pre_colour_map[:ghunnah_2_wowels],
  "FE8E02" => pre_colour_map[:ghunnah_2_wowels],
  "FE8F03" => pre_colour_map[:ghunnah_2_wowels],
  "F1EFEE" => pre_colour_map[:remove],
  "FE0101" => pre_colour_map[:qalqalah],
  "FE0202" => pre_colour_map[:qalqalah],
  "F1EFEF" => pre_colour_map[:remove],
  "9D48A1" => pre_colour_map[:ikhfa],
  "333334" => pre_colour_map[:black_text],
  "9D49A1" => pre_colour_map[:ikhfa],
  "EEEFF1" => pre_colour_map[:remove],
  "3665FE" => pre_colour_map[:madd_obligatory_4_5_vowels],
  "3765FE" => pre_colour_map[:madd_obligatory_4_5_vowels],
  "03A653" => pre_colour_map[:idgham_with_ghunnah],
  "FE8F02" => pre_colour_map[:ghunnah_2_wowels],
  "EDEFF1" => pre_colour_map[:remove],
  "3664FE" => pre_colour_map[:madd_obligatory_4_5_vowels],
  "3766FE" => pre_colour_map[:madd_obligatory_4_5_vowels],
  "EDEDED" => pre_colour_map[:remove],
  "ECEFEE" => pre_colour_map[:remove],
  "EBEFED" => pre_colour_map[:remove],
  "01A651" => pre_colour_map[:idgham_with_ghunnah],
  "C360AD" => pre_colour_map[:ikhfa_shafawi_with_meem],
  "C361AD" => pre_colour_map[:ikhfa_shafawi_with_meem],
  "EFEEEF" => pre_colour_map[:remove],
  "EFF0F1" => pre_colour_map[:remove],
  "7FC865" => pre_colour_map[:idgham_shafawi_with_meem],
  "EFF0EF" => pre_colour_map[:remove],
  "80C866" => pre_colour_map[:idgham_shafawi_with_meem],
  "EFEEF0" => pre_colour_map[:remove],
  "F4BF02" => pre_colour_map[:iqlab],
  "F1F0ED" => pre_colour_map[:remove],
  "F4BF01" => pre_colour_map[:iqlab],
  "EEEEF1" => pre_colour_map[:remove],
  "EFEFF1" => pre_colour_map[:remove],
  "353434" => pre_colour_map[:black_text],
  "F0EFF0" => pre_colour_map[:remove],
  "ECEFF1" => pre_colour_map[:remove],
  "FDFDFD" => pre_colour_map[:remove],
  "EEF0F1" => pre_colour_map[:remove],
  "F1EFED" => pre_colour_map[:remove],
  "F1F0EF" => pre_colour_map[:remove],
  "EEECEF" => pre_colour_map[:remove],
  "333434" => pre_colour_map[:black_text],
  "ECEFED" => pre_colour_map[:remove],
  "EEF0EF" => pre_colour_map[:remove],
  "EFF0EE" => pre_colour_map[:remove],
  "363636" => pre_colour_map[:black_text],
  "F4BF03" => pre_colour_map[:iqlab],
  "F1F0EE" => pre_colour_map[:remove],
  "9D4AA1" => pre_colour_map[:ikhfa],
  "EDF0EF" => pre_colour_map[:remove],
  "7FC866" => pre_colour_map[:idgham_shafawi_with_meem],
  "9E4AA1" => pre_colour_map[:ikhfa],
  "F1EEEE" => pre_colour_map[:remove],
  "03A652" => pre_colour_map[:idgham_with_ghunnah],
  "EFEDEF" => pre_colour_map[:remove],
  "BBB"    => pre_colour_map[:hamzat_wasl],
  "3866FE" => pre_colour_map[:madd_obligatory_4_5_vowels],
  "F0EEEF" => pre_colour_map[:remove],
  "03A753" => pre_colour_map[:idgham_with_ghunnah],
  "353534" => pre_colour_map[:black_text],
  "FE8F04" => pre_colour_map[:ghunnah_2_wowels],
  "80C867" => pre_colour_map[:idgham_shafawi_with_meem],
  "EDEEF1" => pre_colour_map[:remove],
  "343333" => pre_colour_map[:black_text],
  "ECECEC" => pre_colour_map[:remove],
  "F0EEF0" => pre_colour_map[:remove],
  "EDF0EE" => pre_colour_map[:remove],
  "373737" => pre_colour_map[:black_text],
  "343534" => pre_colour_map[:black_text],
  "51BCFE" => pre_colour_map[:madd_normal_2_vowels],
  "EAEEEC" => pre_colour_map[:remove],
  "333433" => pre_colour_map[:black_text],
  "343433" => pre_colour_map[:black_text],
  "343334" => pre_colour_map[:black_text],
  "FCFCFC" => pre_colour_map[:remove],
  "FEFDFE" => pre_colour_map[:remove],
  "FDFEFD" => pre_colour_map[:remove],
  "FDFDFE" => pre_colour_map[:remove],
  "FFFDFB" => pre_colour_map[:remove],
  "FFFCFC" => pre_colour_map[:remove],
  "FDFBFD" => pre_colour_map[:remove],
  "A2A2A2" => pre_colour_map[:hamzat_wasl],
  "2E95FE" => pre_colour_map[:madd_permissible_2_4_6],
  "FEFEFE" => pre_colour_map[:remove],
  "FE0303" => pre_colour_map[:qalqalah],
  "F1F0EC" => pre_colour_map[:remove],
  "EAEFEC" => pre_colour_map[:remove],
  "EEF0EE" => pre_colour_map[:remove],
  "C25FAC" => pre_colour_map[:ikhfa_shafawi_with_meem],
  "C260AC" => pre_colour_map[:ikhfa_shafawi_with_meem],
  "04A754" => pre_colour_map[:idgham_with_ghunnah],
  "EEECEE" => pre_colour_map[:remove],
  "343435" => pre_colour_map[:black_text],
  "ECEDF1" => pre_colour_map[:remove],
  "F0F0EF" => pre_colour_map[:remove],
  "646464" => pre_colour_map[:remove],
  "E9E9E9" => pre_colour_map[:remove],
  "757575" => pre_colour_map[:remove],
  "EBEBEB" => pre_colour_map[:remove],
  "2E94FE" => pre_colour_map[:madd_permissible_2_4_6],
  "EDF0F1" => pre_colour_map[:remove],
  "F1EFEC" => pre_colour_map[:remove],
  "F1EDED" => pre_colour_map[:remove],
  "F1EFEA" => pre_colour_map[:remove],
  "F1BC03" => pre_colour_map[:iqlab],
  "353435" => pre_colour_map[:black_text],
  "F1EFEB" => pre_colour_map[:remove],
  "04A753" => pre_colour_map[:idgham_with_ghunnah],
  "FE0102" => pre_colour_map[:qalqalah],
  "E7E7E7" => pre_colour_map[:remove],
  "2F95FE" => pre_colour_map[:madd_permissible_2_4_6],
  "ABABAB" => pre_colour_map[:hamzat_wasl],
  "2E94FD" => pre_colour_map[:madd_permissible_2_4_6],
  "AFAFAF" => pre_colour_map[:hamzat_wasl],
  "565656" => pre_colour_map[:remove],
  "F1F0F0" => pre_colour_map[:remove],
  "20B166" => pre_colour_map[:idgham_with_ghunnah],
  "242121" => pre_colour_map[:black_text],
  "737373" => pre_colour_map[:remove],
  "656565" => pre_colour_map[:remove],
  "EBEDF1" => pre_colour_map[:remove],
  "FE5F5F" => pre_colour_map[:qalqalah],
  "6D6D6D" => pre_colour_map[:remove],
  "EBECF1" => pre_colour_map[:remove],
  "B578B8" => pre_colour_map[:ikhfa_shafawi_with_meem],
  "7F7F7F" => pre_colour_map[:remove],
  "FE0201" => pre_colour_map[:qalqalah],
  "EAEFED" => pre_colour_map[:remove],
  "F0F0F1" => pre_colour_map[:remove],
  "CDCDCD" => pre_colour_map[:remove],
  "A9A9A9" => pre_colour_map[:hamzat_wasl],
  "DBDBDB" => pre_colour_map[:remove],
  "343535" => pre_colour_map[:black_text],
  "0354C4" => pre_colour_map[:madd_necessary_6_vowels],
  "EFF0F0" => pre_colour_map[:remove],
  "4C4C4C" => pre_colour_map[:remove],
  "D4D4D4" => pre_colour_map[:remove],
  "686868" => pre_colour_map[:remove],
  "6A6A6A" => pre_colour_map[:remove],
  "0353C4" => pre_colour_map[:madd_necessary_6_vowels],
  "707070" => pre_colour_map[:remove],
  "38413D" => pre_colour_map[:remove],
  "7FC765" => pre_colour_map[:idgham_shafawi_with_meem],
  "242021" => pre_colour_map[:black_text],
  "454852" => pre_colour_map[:remove],
  "EBEFF1" => pre_colour_map[:remove],
  "7C7C7C" => pre_colour_map[:remove],
  "80C767" => pre_colour_map[:idgham_shafawi_with_meem],
  "9E4AA2" => pre_colour_map[:ikhfa],
  "AAA8A6" => pre_colour_map[:remove],
  "0152C4" => pre_colour_map[:madd_necessary_6_vowels],
  "EAEEF1" => pre_colour_map[:remove],
  "636363" => pre_colour_map[:remove],
  "3564FE" => pre_colour_map[:madd_obligatory_4_5_vowels],
  "3666FA" => pre_colour_map[:madd_obligatory_4_5_vowels],
  "959595" => pre_colour_map[:remove],
  "5F5F5F" => pre_colour_map[:remove],
  "3B3B3B" => pre_colour_map[:black_text],
  "EAECF1" => pre_colour_map[:remove],
  "616161" => pre_colour_map[:remove],
  "434343" => pre_colour_map[:black_text],
  "ECEEF1" => pre_colour_map[:remove],
  "D6D6D6" => pre_colour_map[:remove],
  "545454" => pre_colour_map[:remove],
  "767676" => pre_colour_map[:remove],
  "898989" => pre_colour_map[:remove],
  "348DE8" => pre_colour_map[:madd_permissible_2_4_6],
  "FD0202" => pre_colour_map[:qalqalah],
  "A1A1A1" => pre_colour_map[:remove],
  "E9EEEC" => pre_colour_map[:remove],
  "3D4441" => pre_colour_map[:remove],
  "D8D8D8" => pre_colour_map[:remove],
  "51BBFE" => pre_colour_map[:madd_normal_2_vowels],
  "F0BD08" => pre_colour_map[:iqlab],
  "E3ECE8" => pre_colour_map[:remove],
  "EAEAEA" => pre_colour_map[:remove],
  "EDBA07" => pre_colour_map[:iqlab],
  "EDEEF0" => pre_colour_map[:remove],
  "5C5C5C" => pre_colour_map[:remove],
  "7FC766" => pre_colour_map[:idgham_shafawi_with_meem],
  "988282" => pre_colour_map[:remove],
  "414141" => pre_colour_map[:remove],
  "515151" => pre_colour_map[:remove],
  "969696" => pre_colour_map[:remove],
  "676767" => pre_colour_map[:remove],
  "C9C9C9" => pre_colour_map[:remove],
  "80C566" => pre_colour_map[:idgham_shafawi_with_meem],
  "81C567" => pre_colour_map[:idgham_shafawi_with_meem],
  "E9EBF1" => pre_colour_map[:remove],
  "E8EEEB" => pre_colour_map[:remove],
  "9B499F" => pre_colour_map[:ikhfa],
  "3C3C3C" => pre_colour_map[:black_text],
  "2E5AA9" => pre_colour_map[:madd_obligatory_4_5_vowels],
  "47A1FE" => pre_colour_map[:madd_normal_2_vowels],
  "466CEC" => pre_colour_map[:madd_obligatory_4_5_vowels],
  "2F5AA9" => pre_colour_map[:madd_obligatory_4_5_vowels],
  "3564FD" => pre_colour_map[:madd_obligatory_4_5_vowels],
  "888"    => pre_colour_map[:remove],
  "DEDEDE" => pre_colour_map[:remove],
  "EFEFEF" => pre_colour_map[:remove],
  "D9D9D9" => pre_colour_map[:remove]
}

def optimise_svg(file_name, index, old_folder, new_folder)
  new_file = file_name.gsub(old_folder, new_folder)
  new_dir = new_file.split('/').tap(&:pop).join("/")

  Dir.mkdir(new_dir) unless File.directory?(new_dir)

  return if File.file?(new_file) && !File.zero?(new_file)

  system "svgo #{file_name} -o #{new_file} --config 'svgo.config.js'"
end

def optimise_colour(file_name, index, old_folder, new_folder)

  text = File.read(file_name)

  new_contents = text.gsub(/(?<=#)(?<!^)(\h{6}|\h{3})/, @colour_map)

  # To merely print the contents of the file, use:
  # puts new_contents
  # exit

  # To write changes to the file, use:
  File.open(file_name, "w") { |file| file.puts new_contents }
end

def optimise_viewbox(file_name, index, old_folder, new_folder)
  # return unless File.foreach(file_name).grep(/viewBox="0\s0/).any?
  input_file  = file_name.gsub(old_folder, new_folder + '/input')
  output_file = file_name.gsub(old_folder, new_folder + '/output')

  new_dir = input_file.split('/').tap(&:pop).join("/")
  type_dir = input_file.split('/').tap(&:pop).last

  Dir.mkdir(new_dir) unless File.directory?(new_dir)

  if File.file?(output_file) && !File.zero?(output_file)
    File.delete(input_file) if File.exists? input_file
  else
    FileUtils.cp(file_name, input_file)
  end

  system "cd /Users/aal29/Github/Personal/svg-autocrop/; npm run fix './input/#{type_dir}/'"

end

Dir.glob("/Users/aal29/Github/Personal/svg0/svgwordopt/*/*.svg").sort.each { |(file_name, index)|
  # optimise_colour(file_name, index, "svgwordopt", "newsvg")
  # optimise_svg(file_name, index, "svgwordopt", "newsvg")
  optimise_viewbox(file_name, index, "svg0/svgwordopt", "svg-autocrop")
}
=end

end