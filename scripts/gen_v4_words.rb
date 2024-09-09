data = []
MushafWord.where(mushaf_id: 19).each do |word|
  data.push({
              text: word.text,
              font: "p#{word.page_number}.ttf",
              filename: "#{word.word.location.gsub(":", "-")}.png"
            })
end

File.open("scripts/v4_words.json", "w") do |f|
  f.write(JSON.pretty_generate(data))
end