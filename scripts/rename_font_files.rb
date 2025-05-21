require 'fileutils'

ttf = "fonts/v1/optimized/ttf/*.ttf"
woff = "/Volumes/Development/static/fonts/quran/hafs/v4-color/woff/*.woff"
woff2 = "/Volumes/Development/static/fonts/quran/hafs/v4-color/woff2/*.woff2"

def rename(path, name_pattern)
  files = Dir[path]

  if files.size.zero?
    puts "No file found for path #{path}"
    return
  end

  files.each do |file|
    old_name = File.basename(file)
    ext = File.extname(file)
    path = File.dirname(file)

    next if ext.to_s.length == 0 # any hidden folder, . and ..

    page = old_name.gsub(name_pattern, '').strip[/\d+/].to_i

    #new_name = "p#{page}#{ext}"
    new_name = "#{name_pattern}#{page.to_s.rjust(3, '0')}#{ext}"
    new_path = "#{path}/#{new_name}"

    if new_path != file
      FileUtils.mv(file, new_path)
      puts "renamed #{new_name}"
    else
      #puts "new and old name is same for #{file}"
    end
  end
end

rename ttf, 'QCF_P'
#rename woff, 'QCF4'
#rename woff2, 'QCF4'