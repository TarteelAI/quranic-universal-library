def compress_woff2(ttf, woff)
  `/Volumes/Development/dev-tools/woff2_compress #{ttf}`
end

def compress_woff(ttf, woff)
  `ttf2woff #{ttf} #{woff}`
end

def move_ttf(ttf, dest)
  `mv #{ttf} #{dest}`
end

1.upto(604).each do |i|
  #ttf = "#{Rails.root}/fonts/app-v1/current/QCF_P#{i.to_s.rjust(3, '0')}.ttf"
  new_ttf = "#{Rails.root}/fonts/app-v1/ttf/p#{i}.ttf"

  woff2 = "#{Rails.root}/fonts/app-v1/woff2/p#{i}.woff2"
  woff = "#{Rails.root}/fonts/app-v1/woff/p#{i}.woff"
  puts "Compressing #{new_ttf}"

  #move_ttf(ttf, new_ttf)
  compress_woff2(new_ttf, woff2)
  compress_woff(new_ttf, woff)

  puts "Done"
end