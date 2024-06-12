number_of_pages = 610

x = "export const loadPage = pageNumber => {
  switch (pageNumber) {\n"
(1..number_of_pages).each do |i|
  x += "case #{i}:\n  return require('./#{i}.json');\n\n"
end
x += "}\n};"

puts x